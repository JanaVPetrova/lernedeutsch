class WordReview < ActiveRecord::Base
  belongs_to :word
  belongs_to :user

  validates :due_date,    presence: true
  validates :ease_factor, numericality: { greater_than_or_equal_to: 1.3 }
  validates :repetitions, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :interval,    numericality: { greater_than: 0, only_integer: true }

  scope :due,      -> { where('due_date <= ?', Time.now) }
  scope :for_user, ->(user) { where(user: user) }
  scope :active,   -> { where(snoozed: false) }
  scope :snoozed,  -> { where(snoozed: true) }

  # Ensure the user has a review row for every word in scope, then return the next due one.
  def self.next_for_user(user, group: nil)
    provision_missing(user, group)
    scope    = apply_group(for_user(user).active.due.joins(:word), group)
    earliest = scope.minimum(:due_date)
    return nil unless earliest

    scope.where(due_date: earliest).to_a.sample
  end

  def self.due_count_for_user(user, group: nil)
    provision_missing(user, group)
    apply_group(for_user(user).active.due.joins(:word), group).count
  end

  # Returns an array of { group:, total:, perfect:, almost:, partial:, wrong:, skipped:, unreviewed: }
  # one entry per group (plus a synthetic entry for ungrouped words).
  def self.stats_for_user(user)
    rows = for_user(user).joins(word: :word_group).select(
      'word_groups.name_ru AS group_name_ru',
      'word_groups.name_de AS group_name_de',
      'word_reviews.last_score'
    ).to_a

    ungrouped_rows = for_user(user).joins(:word).where(words: { word_group_id: nil }).select(
      'word_reviews.last_score'
    ).to_a

    grouped = rows.group_by { |r| [r['group_name_ru'], r['group_name_de']] }.map do |(ru, de), group_rows|
      build_group_stats(ru, de, group_rows)
    end
    ungrouped = ungrouped_rows.empty? ? [] : [build_group_stats('(без группы)', nil, ungrouped_rows)]
    grouped + ungrouped
  end

  def self.build_group_stats(name_ru, name_de, rows)
    total     = rows.size
    scored    = rows.reject { |r| r['last_score'].nil? }
    unreviewed = rows.count { |r| r['last_score'].nil? }
    perfect   = scored.count { |r| r['last_score'].to_i == 100 }
    almost    = scored.count { |r| (75..99).cover?(r['last_score'].to_i) }
    partial   = scored.count { |r| (50..74).cover?(r['last_score'].to_i) }
    wrong     = scored.count { |r| (1..49).cover?(r['last_score'].to_i) }
    skipped   = scored.count { |r| r['last_score'].to_i == 0 }
    { name_ru: name_ru, name_de: name_de, total: total,
      perfect: perfect, almost: almost, partial: partial,
      wrong: wrong, skipped: skipped, unreviewed: unreviewed }
  end
  private_class_method :build_group_stats

  def self.snoozed_for_user(user, group: nil)
    apply_group(for_user(user).snoozed.joins(:word), group).order(:updated_at)
  end

  # Create review rows for any words the user doesn't have one for yet.
  def self.provision_missing(user, group)
    words_scope = apply_group(Word.joins("LEFT JOIN word_reviews ON word_reviews.word_id = words.id AND word_reviews.user_id = #{user.id}"), group)
    missing_words = words_scope.where(word_reviews: { id: nil })
    missing_words.find_each do |word|
      WordReview.create!(
        word:        word,
        user:        user,
        due_date:    Time.now,
        repetitions: 0,
        ease_factor: 2.5,
        interval:    1,
        snoozed:     false
      )
    end
  end
  private_class_method :provision_missing

  def self.apply_group(scope, group)
    case group
    when nil        then scope
    when :ungrouped then scope.where(words: { word_group_id: nil })
    else            scope.where(words: { word_group_id: group.id })
    end
  end
  private_class_method :apply_group
end

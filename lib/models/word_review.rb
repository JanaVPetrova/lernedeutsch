class WordReview < ActiveRecord::Base
  belongs_to :word
  belongs_to :user

  validates :due_session, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :box,         numericality: { in: 1..5, only_integer: true }

  scope :for_user,         ->(user)    { where(user: user) }
  scope :active,           ->          { where(snoozed: false) }
  scope :snoozed,          ->          { where(snoozed: true) }
  scope :due_for_session,  ->(session_n) { where('due_session <= ?', session_n) }

  # Build and return the ordered queue of review IDs for a new session.
  # Also provisions missing reviews for words the user hasn't seen yet.
  def self.queue_for_user(user, group: nil)
    provision_missing(user, group)
    apply_group(
      for_user(user).active.due_for_session(user.sessions_completed).joins(:word),
      group
    ).order(:due_session, :id).pluck(:id).shuffle
  end

  def self.due_count_for_user(user, group: nil)
    provision_missing(user, group)
    apply_group(
      for_user(user).active.due_for_session(user.sessions_completed).joins(:word),
      group
    ).count
  end

  def self.snoozed_for_user(user, group: nil)
    apply_group(for_user(user).snoozed.joins(:word), group).order(:updated_at)
  end

  # Returns an array of { name_ru:, name_de:, total:, perfect:, almost:, partial:, wrong:, skipped:, unreviewed: }
  def self.stats_for_user(user)
    provision_missing(user, nil)

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
    total      = rows.size
    scores     = rows.map { |r| r.respond_to?(:last_score) ? r.last_score : r['last_score'] }
    scored     = scores.compact
    unreviewed = scores.count(&:nil?)
    perfect    = scored.count { |s| s == 100 }
    almost     = scored.count { |s| (75..99).cover?(s) }
    partial    = scored.count { |s| (50..74).cover?(s) }
    wrong      = scored.count { |s| (1..49).cover?(s) }
    skipped    = scored.count { |s| s == 0 }
    { name_ru: name_ru, name_de: name_de, total: total,
      perfect: perfect, almost: almost, partial: partial,
      wrong: wrong, skipped: skipped, unreviewed: unreviewed }
  end
  private_class_method :build_group_stats

  # Create review rows for any words the user doesn't have one for yet.
  def self.provision_missing(user, group)
    words_scope = apply_group(
      Word.joins("LEFT JOIN word_reviews ON word_reviews.word_id = words.id AND word_reviews.user_id = #{user.id}"),
      group
    )
    words_scope.where(word_reviews: { id: nil }).find_each do |word|
      WordReview.create!(
        word:        word,
        user:        user,
        due_session: 0,
        box:         1,
        snoozed:     false
      )
    end
  end
  private_class_method :provision_missing

  def self.apply_group(scope, group)
    case group
    when nil        then scope
    when :ungrouped then scope.where(words: { word_group_id: nil })
    else                 scope.where(words: { word_group_id: group.id })
    end
  end
  private_class_method :apply_group
end

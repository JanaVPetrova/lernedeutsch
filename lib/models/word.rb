class Word < ActiveRecord::Base
  belongs_to :word_group, optional: true
  has_many   :word_reviews, dependent: :destroy

  validates :de,         presence: true
  validates :ru,         presence: true
  validates :article_de, inclusion: { in: ARTICLES = %w[der die das], allow_nil: true,
                                      message: 'must be der, die, or das' }
  validates :de_normalized, uniqueness: { scope: :ru_normalized },
            if: -> { de_normalized.present? }

  before_validation :set_normalized

  def self.normalize(str)
    str.to_s.downcase.gsub(/[\s[:punct:]]/, '')
  end

  # Plain answer form — used for scoring, labels, snoozed list matching.
  def full_german
    article_de ? "#{article_de} #{de}" : de
  end

  # Plain answer form — used for scoring and "correct answer" display.
  def display_translation
    ru
  end

  # Prompt form for DE→RU mode: includes DE context hint in italics when present.
  def prompt_de
    de_context.present? ? "#{full_german} _#{de_context}_" : full_german
  end

  # Prompt form for RU→DE mode: includes RU context hint in italics when present.
  def prompt_ru
    ru_context.present? ? "#{ru} _#{ru_context}_" : ru
  end

  # All accepted German forms: every Word sharing the same ru_normalized.
  def alternatives_de
    Word.where(ru_normalized: ru_normalized).map(&:full_german)
  end

  # All accepted translations: every Word sharing the same de_normalized.
  def alternatives_translation
    Word.where(de_normalized: de_normalized).pluck(:ru)
  end

  private

  def set_normalized
    self.de_normalized = Word.normalize(de)
    self.ru_normalized = Word.normalize(ru)
  end
end

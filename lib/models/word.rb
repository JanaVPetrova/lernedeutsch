class Word < ActiveRecord::Base
  belongs_to :word_group, optional: true
  has_many   :word_reviews, dependent: :destroy

  validates :german_word,  presence: true
  validates :translation,  presence: true
  validates :german_word,  uniqueness: { case_sensitive: false }
  validates :article, inclusion: { in: ARTICLES = %w[der die das], allow_nil: true,
                                   message: 'must be der, die, or das' }

  def full_german
    article ? "#{article} #{german_word}" : german_word
  end
end

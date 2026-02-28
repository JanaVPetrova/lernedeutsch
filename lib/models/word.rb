class Word < ActiveRecord::Base
  belongs_to :user
  has_one    :word_review, dependent: :destroy

  validates :german_word,  presence: true
  validates :translation,  presence: true
  validates :german_word,  uniqueness: { scope: :user_id, case_sensitive: false }
  validates :article, inclusion: { in: ARTICLES = %w[der die das], allow_nil: true,
                                   message: 'must be der, die, or das' }

  after_create :initialize_review

  def full_german
    article ? "#{article} #{german_word}" : german_word
  end

  private

  def initialize_review
    WordReview.create!(
      word:        self,
      user:        user,
      due_date:    Date.today,
      repetitions: 0,
      ease_factor: 2.5,
      interval:    1
    )
  end
end

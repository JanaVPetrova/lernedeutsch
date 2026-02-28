class WordReview < ActiveRecord::Base
  belongs_to :word
  belongs_to :user

  validates :due_date,    presence: true
  validates :ease_factor, numericality: { greater_than_or_equal_to: 1.3 }
  validates :repetitions, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :interval,    numericality: { greater_than: 0, only_integer: true }

  scope :due,      -> { where('due_date <= ?', Date.today) }
  scope :for_user, ->(user) { where(user: user) }

  def self.next_for_user(user)
    for_user(user).due.joins(:word).order(:due_date).first
  end
end

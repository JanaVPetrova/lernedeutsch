class User < ActiveRecord::Base
  has_many :words, dependent: :destroy
  has_many :word_reviews, dependent: :destroy
  has_one  :reminder, dependent: :destroy

  validates :telegram_id, presence: true, uniqueness: true

  def self.find_or_create_from_telegram(telegram_user)
    find_or_create_by(telegram_id: telegram_user.id) do |u|
      u.first_name = telegram_user.first_name
      u.last_name  = telegram_user.last_name
      u.username   = telegram_user.username
    end
  end

  def display_name
    first_name || username || "User #{telegram_id}"
  end
end

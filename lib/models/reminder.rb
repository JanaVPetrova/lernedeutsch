class Reminder < ActiveRecord::Base
  belongs_to :user

  ALL_DAYS = %w[mon tue wed thu fri sat sun].freeze

  validates :time, presence: true, format: { with: /\A\d{2}:\d{2}\z/, message: 'must be HH:MM' }
  validates :user_id, uniqueness: true
  validate  :days_must_be_valid

  def self.parse_days(input)
    case input.strip.downcase
    when 'all'      then ALL_DAYS.dup
    when 'weekdays' then %w[mon tue wed thu fri]
    when 'weekend'  then %w[sat sun]
    else
      input.strip.downcase.split(',').map(&:strip).select { |d| ALL_DAYS.include?(d) }
    end
  end

  def due_now?
    return false unless enabled

    today = Time.now.strftime('%a').downcase
    days.include?(today) && time == Time.now.strftime('%H:%M')
  end

  private

  def days_must_be_valid
    return if days.is_a?(Array) && days.all? { |d| ALL_DAYS.include?(d) }

    errors.add(:days, 'must be an array of valid day abbreviations (mon-sun)')
  end
end

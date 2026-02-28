require 'net/http'

# Runs in a background thread, checking every 60 seconds whether any user
# reminders are due and sending them a Telegram message if so.
class ReminderScheduler
  def self.start(token)
    Thread.new do
      loop do
        sleep(60)
        check_and_send(token)
      rescue StandardError => e
        warn "[ReminderScheduler] #{e.class}: #{e.message}"
      end
    end
  end

  def self.check_and_send(token)
    Reminder.where(enabled: true).includes(:user).each do |reminder|
      next unless reminder.due_now?

      user      = reminder.user
      due_count = WordReview.for_user(user).due.count
      next if due_count.zero?

      send_message(token, user.telegram_id,
                   "🔔 Time to practice your German!\n\n" \
                   "You have #{due_count} word#{due_count == 1 ? '' : 's'} due for review.\n\n" \
                   "Send /start to begin!")
    end
  end

  def self.send_message(token, chat_id, text)
    uri = URI("https://api.telegram.org/bot#{token}/sendMessage")
    Net::HTTP.post_form(uri, { chat_id: chat_id, text: text })
  end
end

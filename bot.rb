require 'logger'
require 'telegram/bot'
require_relative 'lib/boot'

TOKEN = ENV.fetch('TELEGRAM_BOT_TOKEN') { raise 'TELEGRAM_BOT_TOKEN is not set' }

MAIN_KEYBOARD = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
  keyboard: [['German → Translation', 'Translation → German'], ['Upload Words', 'Set Reminder']],
  resize_keyboard: true
)

SESSIONS = Hash.new { |h, k| h[k] = {} }
LOGGER   = Logger.new($stdout)

# ── Helpers ───────────────────────────────────────────────────────────────────

def show_main_menu(bot, message)
  user = User.find_or_create_from_telegram(message.from)
  bot.api.send_message(
    chat_id: message.chat.id,
    text: "Welcome back, #{user.display_name}! Choose what to do:",
    reply_markup: MAIN_KEYBOARD
  )
end

def enter_upload_scene(bot, chat_id, session)
  session[:scene] = :upload_words
  bot.api.send_message(chat_id: chat_id, parse_mode: 'Markdown', text: <<~TEXT)
    Send me your word list as a *.csv* or *.txt* file, or just paste the words here.

    Format – one pair per line:
    ```
    german_word,your_translation
    der Hund,dog
    die Katze,cat
    gehen,to go
    ```
    The article (*der/die/das*) is optional.
  TEXT
end

def enter_reminder_scene(bot, chat_id, session)
  session[:scene]      = :set_reminder
  session[:scene_step] = :awaiting_time
  bot.api.send_message(
    chat_id: chat_id,
    parse_mode: 'Markdown',
    text: "At what time should I remind you to study?\n\nPlease reply in *HH:MM* format (e.g. _09:00_ or _18:30_)."
  )
end

# ── Bot ───────────────────────────────────────────────────────────────────────

ReminderScheduler.start(TOKEN)

Telegram::Bot::Client.run(TOKEN) do |bot|
  bot.listen do |message|
    next unless message.is_a?(Telegram::Bot::Types::Message)
    next unless message.from

    chat_id = message.chat.id
    session = SESSIONS[message.from.id]
    text    = message.text

    User.find_or_create_from_telegram(message.from)

    LOGGER.info("[msg] user=#{message.from.id} scene=#{session[:scene] || 'none'} mode=#{session[:mode] || 'none'} text=#{text.inspect}")

    # ── Commands ──────────────────────────────────────────────────────────────

    if text&.start_with?('/')
      cmd = text.split.first.delete_prefix('/').split('@').first

      case cmd
      when 'start'
        session.clear
        user = User.find_or_create_from_telegram(message.from)
        bot.api.send_message(
          chat_id: chat_id,
          text: "👋 Hallo, #{user.display_name}! Let's learn some German.",
          reply_markup: MAIN_KEYBOARD
        )
      when 'stop'
        session.clear
        show_main_menu(bot, message)
      when 'learn'
        LOGGER.info("[nav] user=#{message.from.id} requested learn mode selection")
        show_main_menu(bot, message)
      when 'upload'
        LOGGER.info("[nav] user=#{message.from.id} entering upload_words scene")
        enter_upload_scene(bot, chat_id, session)
      when 'reminder'
        LOGGER.info("[nav] user=#{message.from.id} entering set_reminder scene")
        enter_reminder_scene(bot, chat_id, session)
      end

      next
    end

    # ── Scene: upload_words ───────────────────────────────────────────────────

    if session[:scene] == :upload_words
      user    = User.find_or_create_from_telegram(message.from)
      content = if message.document
                  WordImporter.download_document(message.document.file_id, TOKEN)
                elsif text
                  text
                end

      if content.nil? || content.strip.empty?
        bot.api.send_message(
          chat_id: chat_id,
          text: "Couldn't read that. Please send a .csv/.txt file or paste your words directly."
        )
        session[:scene] = nil
        next
      end

      words_data = WordImporter.parse(content)
      if words_data.empty?
        bot.api.send_message(
          chat_id: chat_id,
          text: "No valid word pairs found. Check the format (german,translation) and try again."
        )
        session[:scene] = nil
        next
      end

      count   = WordImporter.import(user, words_data)
      skipped = words_data.length - count
      msg     = "✅ Added *#{count}* new word#{count == 1 ? '' : 's'}!"
      msg    += "\n_(#{skipped} already existed and were skipped)_" if skipped > 0
      bot.api.send_message(chat_id: chat_id, text: msg, parse_mode: 'Markdown', reply_markup: MAIN_KEYBOARD)
      session[:scene] = nil
      next
    end

    # ── Scene: set_reminder ───────────────────────────────────────────────────

    if session[:scene] == :set_reminder
      case session[:scene_step]
      when :awaiting_time
        unless text&.match?(/\A\d{2}:\d{2}\z/)
          bot.api.send_message(
            chat_id: chat_id,
            text: "That doesn't look like a valid time. Please use HH:MM (e.g. 09:00)."
          )
          session[:scene] = nil
          next
        end

        session[:reminder_time] = text.strip
        session[:scene_step]    = :awaiting_days
        bot.api.send_message(
          chat_id: chat_id,
          parse_mode: 'Markdown',
          text: "Great! Which days?\n\nType *all*, *weekdays*, *weekend*, or list specific days like _mon,wed,fri_."
        )

      when :awaiting_days
        user       = User.find_or_create_from_telegram(message.from)
        days_input = text.strip.downcase
        days       = Reminder.parse_days(days_input)

        if days.empty?
          bot.api.send_message(
            chat_id: chat_id,
            text: "I didn't recognise those days. Use: all, weekdays, weekend, or specific abbreviations like mon,tue,wed."
          )
          session[:scene] = nil
          next
        end

        reminder = Reminder.find_or_initialize_by(user: user)
        reminder.update!(time: session[:reminder_time], days: days, enabled: true)

        days_str = days_input == 'all' ? 'every day' : days.join(', ')
        bot.api.send_message(
          chat_id: chat_id,
          parse_mode: 'Markdown',
          text: "✅ Reminder set for *#{session[:reminder_time]}* on #{days_str}!",
          reply_markup: MAIN_KEYBOARD
        )
        session[:scene] = nil
      end

      next
    end

    # ── Learning / main menu ──────────────────────────────────────────────────

    if session[:mode]
      LOGGER.info("[learn] user=#{message.from.id} answering in mode=#{session[:mode]}")
      LearningHandler.new(bot, message, session).handle_answer
    else
      case text
      when 'German → Translation'
        LOGGER.info("[nav] user=#{message.from.id} starting learn_de_to_native")
        LearningHandler.new(bot, message, session).start('learn_de_to_native')
      when 'Translation → German'
        LOGGER.info("[nav] user=#{message.from.id} starting learn_native_to_de")
        LearningHandler.new(bot, message, session).start('learn_native_to_de')
      when 'Upload Words'
        LOGGER.info("[nav] user=#{message.from.id} entering upload_words scene")
        enter_upload_scene(bot, chat_id, session)
      when 'Set Reminder'
        LOGGER.info("[nav] user=#{message.from.id} entering set_reminder scene")
        enter_reminder_scene(bot, chat_id, session)
      else
        LOGGER.info("[nav] user=#{message.from.id} unhandled text: #{text.inspect}")
      end
    end
  rescue StandardError => e
    LOGGER.error("[error] #{e.class}: #{e.message}\n#{e.backtrace.first(3).join("\n")}")
  end
end

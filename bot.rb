$stdout.sync = true

require 'logger'
require 'telegram/bot'
require_relative 'lib/boot'

TOKEN = ENV.fetch('TELEGRAM_BOT_TOKEN') { raise 'TELEGRAM_BOT_TOKEN is not set' }

MAIN_KEYBOARD = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
  keyboard: [
    [MSGS[:btn_de_to_ru],  MSGS[:btn_ru_to_de]],
    [MSGS[:btn_upload],    MSGS[:btn_snoozed]],
    [MSGS[:btn_stats]]
  ],
  resize_keyboard: true
)

SESSIONS = Hash.new { |h, k| h[k] = {} }
LOGGER   = Logger.new($stdout)
LOGGER.level = Logger::INFO

# ── Helpers ───────────────────────────────────────────────────────────────────

def show_main_menu(bot, message)
  user = User.find_or_create_from_telegram(message.from)
  bot.api.send_message(
    chat_id: message.chat.id,
    text: MSGS[:welcome_back].call(user.display_name),
    reply_markup: MAIN_KEYBOARD
  )
end

def enter_upload_scene(bot, chat_id, session, user)
  session[:scene] = :upload_words
  groups = WordGroup.order(:name_ru)

  if groups.empty?
    session[:scene_step] = :awaiting_name_ru
    bot.api.send_message(chat_id: chat_id, text: MSGS[:upload_ask_name_ru])
  else
    session[:scene_step] = :awaiting_group_pick
    labels  = groups.map { |g| "#{g.name_ru} / #{g.name_de}" } + [MSGS[:btn_upload_new_group]]
    markup  = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: labels.each_slice(2).to_a,
      resize_keyboard: true,
      one_time_keyboard: true
    )
    bot.api.send_message(chat_id: chat_id, text: MSGS[:upload_pick_group], reply_markup: markup)
  end
end

def show_group_menu(bot, chat_id, user)
  groups        = WordGroup.order(:name_ru)

  options  = groups.map { |g| "#{g.name_ru} / #{g.name_de}" }
  options << MSGS[:btn_all_words]

  markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
    keyboard: options.each_slice(2).to_a,
    resize_keyboard: true,
    one_time_keyboard: true
  )
  bot.api.send_message(chat_id: chat_id, text: MSGS[:pick_group_prompt], reply_markup: markup)
end

def enter_reminder_scene(bot, chat_id, session)
  session[:scene]      = :set_reminder
  session[:scene_step] = :awaiting_time
  bot.api.send_message(chat_id: chat_id, parse_mode: 'Markdown', text: MSGS[:reminder_ask_time])
end

# ── Bot ───────────────────────────────────────────────────────────────────────

ReminderScheduler.start(TOKEN)

Telegram::Bot::Client.run(TOKEN) do |bot|
  bot.listen do |message|
    if message.is_a?(Telegram::Bot::Types::CallbackQuery)
      session = SESSIONS[message.from.id]
      LOGGER.info("[callback] user=#{message.from.id} data=#{message.data.inspect}")
      bot.api.answer_callback_query(callback_query_id: message.id)

      if message.data&.start_with?('report_mistake:')
        review_id = message.data.split(':').last.to_i
        fake_msg  = message.message.tap { |m| m.instance_variable_set(:@from, message.from) }
        LearningHandler.new(bot, fake_msg, session).handle_report_mistake(review_id)
      end
      next
    end

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
          text: MSGS[:welcome].call(user.display_name),
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
        enter_upload_scene(bot, chat_id, session, User.find_or_create_from_telegram(message.from))
      when 'reminder'
        LOGGER.info("[nav] user=#{message.from.id} entering set_reminder scene")
        enter_reminder_scene(bot, chat_id, session)
      end

      next
    end

    # ── Scene: upload_words ───────────────────────────────────────────────────

    if session[:scene] == :upload_words
      if session[:scene_step] == :awaiting_group_pick
        user   = User.find_or_create_from_telegram(message.from)
        groups = WordGroup.order(:name_ru)
        valid  = groups.map { |g| "#{g.name_ru} / #{g.name_de}" } + [MSGS[:btn_upload_new_group]]

        unless valid.include?(text)
          bot.api.send_message(chat_id: chat_id, text: MSGS[:upload_pick_group])
          next
        end

        if text == MSGS[:btn_upload_new_group]
          session[:scene_step] = :awaiting_name_ru
          bot.api.send_message(chat_id: chat_id, text: MSGS[:upload_ask_name_ru])
        else
          group = groups.find { |g| "#{g.name_ru} / #{g.name_de}" == text }
          session[:upload_group_id] = group.id
          session[:scene_step]      = :awaiting_words
          bot.api.send_message(
            chat_id: chat_id,
            parse_mode: 'Markdown',
            text: MSGS[:upload_ask_words].call(group.name_ru, group.name_de)
          )
        end
        next
      end

      if session[:scene_step] == :awaiting_name_ru
        if text.nil? || text.strip.empty?
          bot.api.send_message(chat_id: chat_id, text: MSGS[:upload_ask_name_ru_retry])
          next
        end

        session[:upload_name_ru] = text.strip
        session[:scene_step]     = :awaiting_name_de
        bot.api.send_message(chat_id: chat_id, text: MSGS[:upload_ask_name_de])
        next
      end

      if session[:scene_step] == :awaiting_name_de
        if text.nil? || text.strip.empty?
          bot.api.send_message(chat_id: chat_id, text: MSGS[:upload_ask_name_de_retry])
          next
        end

        session[:upload_name_de] = text.strip
        session[:scene_step]     = :awaiting_words
        bot.api.send_message(
          chat_id: chat_id,
          parse_mode: 'Markdown',
          text: MSGS[:upload_ask_words].call(session[:upload_name_ru], session[:upload_name_de])
        )
        next
      end

      user    = User.find_or_create_from_telegram(message.from)
      content = if message.document
                  WordImporter.download_document(message.document.file_id, TOKEN)
                elsif text
                  text
                end

      if content.nil? || content.strip.empty?
        bot.api.send_message(chat_id: chat_id, text: MSGS[:upload_unreadable])
        session[:scene] = nil
        next
      end

      words_data = WordImporter.parse(content)
      if words_data.empty?
        bot.api.send_message(chat_id: chat_id, text: MSGS[:upload_no_pairs])
        session[:scene] = nil
        next
      end

      word_group = if session[:upload_group_id]
                     WordGroup.find(session[:upload_group_id])
                   else
                     WordGroup.create!(
                       name_ru: session[:upload_name_ru],
                       name_de: session[:upload_name_de]
                     )
                   end
      count   = WordImporter.import(words_data, word_group: word_group)
      skipped = words_data.length - count
      msg     = MSGS[:upload_done].call(count, word_group.name_ru, word_group.name_de)
      msg    += MSGS[:upload_skipped].call(skipped) if skipped > 0
      bot.api.send_message(chat_id: chat_id, text: msg, parse_mode: 'Markdown', reply_markup: MAIN_KEYBOARD)
      session[:scene]           = nil
      session[:upload_name_ru]  = nil
      session[:upload_name_de]  = nil
      session[:upload_group_id] = nil
      next
    end

    # ── Scene: set_reminder ───────────────────────────────────────────────────

    if session[:scene] == :set_reminder
      case session[:scene_step]
      when :awaiting_time
        unless text&.match?(/\A\d{2}:\d{2}\z/)
          bot.api.send_message(chat_id: chat_id, text: MSGS[:reminder_bad_time])
          session[:scene] = nil
          next
        end

        session[:reminder_time] = text.strip
        session[:scene_step]    = :awaiting_days
        bot.api.send_message(chat_id: chat_id, parse_mode: 'Markdown', text: MSGS[:reminder_ask_days])

      when :awaiting_days
        user = User.find_or_create_from_telegram(message.from)
        days = Reminder.parse_days(text.strip.downcase)

        if days.empty?
          bot.api.send_message(chat_id: chat_id, text: MSGS[:reminder_bad_days])
          session[:scene] = nil
          next
        end

        reminder = Reminder.find_or_initialize_by(user: user)
        reminder.update!(time: session[:reminder_time], days: days, enabled: true)

        days_str = days.length == 7 ? 'каждый день' : days.join(', ')
        bot.api.send_message(
          chat_id: chat_id,
          parse_mode: 'Markdown',
          text: MSGS[:reminder_done].call(session[:reminder_time], days_str),
          reply_markup: MAIN_KEYBOARD
        )
        session[:scene] = nil
      end

      next
    end

    # ── Scene: pick_group ─────────────────────────────────────────────────────

    if session[:scene] == :pick_group
      user   = User.find_or_create_from_telegram(message.from)
      groups = WordGroup.order(:name_ru)
      valid  = groups.map { |g| "#{g.name_ru} / #{g.name_de}" } + [MSGS[:btn_no_group], MSGS[:btn_all_words]]

      unless valid.include?(text)
        LOGGER.info("[nav] user=#{message.from.id} invalid group choice: #{text.inspect}")
        next
      end

      chosen_group = case text
                     when MSGS[:btn_all_words] then nil
                     when MSGS[:btn_no_group]  then :ungrouped
                     else groups.find { |g| "#{g.name_ru} / #{g.name_de}" == text }
                     end

      session[:scene]        = nil
      session[:word_group]   = chosen_group
      mode                   = session[:pending_mode]
      session[:pending_mode] = nil

      LOGGER.info("[nav] user=#{message.from.id} group=#{chosen_group.inspect} starting mode=#{mode}")
      LearningHandler.new(bot, message, session).start(mode)
      next
    end

    # ── Scene: edit_word ─────────────────────────────────────────────────────

    if session[:scene] == :edit_word
      review = WordReview.find_by(id: session[:edit_review_id])
      unless review
        session[:scene] = nil
        session[:mode]  = session.delete(:edit_saved_mode)
        next
      end
      word = review.word

      if session[:scene_step] == :awaiting_translation
        session[:edit_new_translation] = text.strip
        session[:scene_step]           = :awaiting_german
        bot.api.send_message(
          chat_id: chat_id,
          parse_mode: 'Markdown',
          text: MSGS[:edit_ask_german].call(word.full_german)
        )
        next
      end

      if session[:scene_step] == :awaiting_german
        article, german_word = WordImporter.split_article(text.strip)
        if word.update(translation: session[:edit_new_translation], german_word: german_word, article: article)
          bot.api.send_message(chat_id: chat_id, text: MSGS[:edit_done])
        else
          bot.api.send_message(chat_id: chat_id, text: MSGS[:edit_invalid_german])
        end

        session[:scene]                = nil
        session[:edit_review_id]       = nil
        session[:edit_new_translation] = nil
        session[:mode]                 = session.delete(:edit_saved_mode)
        LearningHandler.new(bot, message, session).show_next_word
        next
      end
    end

    # ── Scene: snoozed_words ─────────────────────────────────────────────────

    if session[:scene] == :snoozed_words
      user    = User.find_or_create_from_telegram(message.from)
      reviews = WordReview.snoozed_for_user(user).to_a
      labels  = reviews.map { |r| r.word.full_german }
      valid   = labels + [MSGS[:btn_back]]

      unless valid.include?(text)
        LOGGER.info("[nav] user=#{message.from.id} unknown snoozed pick: #{text.inspect}")
        next
      end

      if text == MSGS[:btn_back]
        session[:scene] = nil
        show_main_menu(bot, message)
        next
      end

      review = reviews.find { |r| r.word.full_german == text }
      review.update!(snoozed: false)
      bot.api.send_message(
        chat_id: chat_id,
        parse_mode: 'Markdown',
        text: MSGS[:unsnoozed_done].call(text)
      )

      # Refresh the list after unsnoozing
      remaining = WordReview.snoozed_for_user(user).to_a
      if remaining.empty?
        bot.api.send_message(chat_id: chat_id, text: MSGS[:snoozed_list_empty], reply_markup: MAIN_KEYBOARD)
        session[:scene] = nil
      else
        labels   = remaining.map { |r| r.word.full_german } + [MSGS[:btn_back]]
        markup   = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: labels.each_slice(2).to_a,
          resize_keyboard: true
        )
        bot.api.send_message(chat_id: chat_id, text: MSGS[:snoozed_list_header], reply_markup: markup)
      end
      next
    end

    # ── Learning / main menu ──────────────────────────────────────────────────

    if session[:mode]
      LOGGER.info("[learn] user=#{message.from.id} answering in mode=#{session[:mode]}")
      LearningHandler.new(bot, message, session).handle_answer
    else
      case text
      when MSGS[:btn_de_to_ru], MSGS[:btn_ru_to_de]
        mode = text == MSGS[:btn_de_to_ru] ? 'learn_de_to_native' : 'learn_native_to_de'
        LOGGER.info("[nav] user=#{message.from.id} mode=#{mode} entering group picker")
        user = User.find_or_create_from_telegram(message.from)
        session[:scene]        = :pick_group
        session[:pending_mode] = mode
        show_group_menu(bot, chat_id, user)
      when MSGS[:btn_upload]
        LOGGER.info("[nav] user=#{message.from.id} entering upload_words scene")
        user = User.find_or_create_from_telegram(message.from)
        enter_upload_scene(bot, chat_id, session, user)
      when MSGS[:btn_reminder]
        LOGGER.info("[nav] user=#{message.from.id} entering set_reminder scene")
        enter_reminder_scene(bot, chat_id, session)
      when MSGS[:btn_stats]
        LOGGER.info("[nav] user=#{message.from.id} requested stats")
        user   = User.find_or_create_from_telegram(message.from)
        groups = WordReview.stats_for_user(user).reject { |g| g[:total] == 0 }
        if groups.empty?
          bot.api.send_message(chat_id: chat_id, text: MSGS[:stats_no_data])
        else
          body = groups.map { |g| MSGS[:stats_group].call(g) }.join("\n\n")
          bot.api.send_message(
            chat_id: chat_id,
            parse_mode: 'Markdown',
            text: "#{MSGS[:stats_header]}\n#{body}"
          )
        end
      when MSGS[:btn_snoozed]
        LOGGER.info("[nav] user=#{message.from.id} entering snoozed_words scene")
        user    = User.find_or_create_from_telegram(message.from)
        reviews = WordReview.snoozed_for_user(user).to_a
        if reviews.empty?
          bot.api.send_message(chat_id: chat_id, text: MSGS[:snoozed_list_empty], reply_markup: MAIN_KEYBOARD)
        else
          session[:scene] = :snoozed_words
          labels  = reviews.map { |r| r.word.full_german } + [MSGS[:btn_back]]
          markup  = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
            keyboard: labels.each_slice(2).to_a,
            resize_keyboard: true
          )
          bot.api.send_message(chat_id: chat_id, text: MSGS[:snoozed_list_header], reply_markup: markup)
        end
      else
        LOGGER.info("[nav] user=#{message.from.id} unhandled text: #{text.inspect}")
      end
    end
  rescue StandardError => e
    LOGGER.error("[error] #{e.class}: #{e.message}\n#{e.backtrace.first(3).join("\n")}")
  end
end

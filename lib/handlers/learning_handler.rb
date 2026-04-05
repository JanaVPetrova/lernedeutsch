class LearningHandler
  LEARNING_KEYBOARD = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
    keyboard: [
      [MSGS[:btn_skip], MSGS[:btn_snooze]],
      [MSGS[:btn_back]]
    ],
    resize_keyboard: true
  )

  def self.report_button(review_id)
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [[
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          MSGS[:btn_report_mistake],
          callback_data: "report_mistake:#{review_id}"
        )
      ]]
    )
  end

  def initialize(bot, message, session)
    @bot     = bot
    @message = message
    @session = session
    @chat_id = message.chat.id
  end

  def start(mode)
    @session[:mode]            = mode
    @session[:reviewed_count]  = 0
    @session[:session_results] = []
    show_next_word
  end

  def show_next_word
    user   = User.find_or_create_from_telegram(@message.from)
    group  = @session[:word_group]
    review = WordReview.next_for_user(user, group: group)

    unless review
      reviewed = @session[:reviewed_count] || 0
      msg = reviewed > 0 ? MSGS[:learn_all_done].call(reviewed) : MSGS[:learn_no_words]
      reply msg, reply_markup: MAIN_KEYBOARD
      clear_session
      return
    end

    @session[:current_review_id] = review.id
    word      = review.word
    due_count = WordReview.due_count_for_user(user, group: group)

    prompt = if @session[:mode] == 'learn_de_to_native'
               MSGS[:learn_prompt_de_to_ru].call(word.full_german)
             else
               MSGS[:learn_prompt_ru_to_de].call(word.translation)
             end

    reply "#{MSGS[:learn_progress].call(due_count)}\n\n#{prompt}",
          parse_mode: 'Markdown',
          reply_markup: LEARNING_KEYBOARD
  end

  def handle_answer
    review = WordReview.find_by(id: @session[:current_review_id])
    unless review
      @session[:mode] = nil
      user = User.find_or_create_from_telegram(@message.from)
      reply MSGS[:welcome_back].call(user.display_name), reply_markup: MAIN_KEYBOARD
      return
    end

    word     = review.word
    expected = @session[:mode] == 'learn_de_to_native' ? word.translation : word.full_german

    case @message.text
    when MSGS[:btn_back]
      show_stats_and_return

    when MSGS[:btn_snooze]
      review.update!(snoozed: true)
      reply MSGS[:snoozed_done], parse_mode: 'Markdown'
      show_next_word

    when MSGS[:btn_skip]
      SpacedRepetition.update(review, 0)
      record_result(word, 0)
      @session[:reviewed_count]          = (@session[:reviewed_count] || 0) + 1
      @session[:last_answered_review_id] = review.id
      reply "#{MSGS[:feedback_empty]}\n#{MSGS[:learn_correct_answer].call(expected)}",
            parse_mode: 'Markdown',
            reply_markup: LearningHandler.report_button(review.id)
      show_next_word

    else
      score = AnswerScorer.score(expected: expected, given: @message.text)
      SpacedRepetition.update(review, score)
      record_result(word, score)
      @session[:reviewed_count] = (@session[:reviewed_count] || 0) + 1

      text = feedback_for(score)
      text += "\n#{MSGS[:learn_correct_answer].call(expected)}" if score < 100
      reply text, parse_mode: 'Markdown', reply_markup: LearningHandler.report_button(review.id)
      show_next_word
    end
  end

  def handle_report_mistake(review_id)
    target_review = WordReview.find_by(id: review_id)
    return unless target_review

    word = target_review.word
    @session[:scene]           = :edit_word
    @session[:scene_step]      = :awaiting_translation
    @session[:edit_review_id]  = review_id
    @session[:edit_saved_mode] = @session[:mode]
    @session[:mode]            = nil
    reply MSGS[:edit_ask_translation].call(word.full_german, word.translation),
          parse_mode: 'Markdown',
          reply_markup: Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
  end

  private

  def record_result(word, score)
    @session[:session_results] ||= []
    @session[:session_results] << { word: word.full_german, translation: word.translation, score: score }
  end

  def show_stats_and_return
    results = @session[:session_results] || []
    msg = if results.empty?
            MSGS[:learn_session_none]
          else
            MSGS[:learn_session_stats].call(results)
          end
    reply msg, parse_mode: 'Markdown', reply_markup: MAIN_KEYBOARD
    clear_session
  end

  def clear_session
    @session[:mode]              = nil
    @session[:current_review_id] = nil
    @session[:reviewed_count]    = nil
    @session[:word_group]        = nil
    @session[:session_results]   = nil
  end

  def feedback_for(score)
    case score
    when 100    then MSGS[:feedback_perfect]
    when 75..99 then MSGS[:feedback_almost].call(score)
    when 50..74 then MSGS[:feedback_partial].call(score)
    when 1..49  then MSGS[:feedback_wrong].call(score)
    else             MSGS[:feedback_empty]
    end
  end

  def reply(text, **opts)
    @bot.api.send_message(chat_id: @chat_id, text: text, **opts)
  end
end

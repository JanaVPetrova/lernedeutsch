class LearningHandler
  LEARNING_KEYBOARD = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
    keyboard: [
      [MSGS[:btn_skip], MSGS[:btn_hint]],
      [MSGS[:btn_snooze], MSGS[:btn_back]]
    ],
    resize_keyboard: true
  )

  # Re-insertion positions in the session queue for wrong/partial answers.
  REINSERT_POSITIONS = {
    (0..0)   => 1,  # skip:    see it after 1 word
    (1..49)  => 1,  # wrong:   see it after 1 word
    (50..74) => 2,  # partial: see it after 2 words
    (75..99) => 3,  # almost:  see it after 3 words
  }.freeze

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
    user = User.find_or_create_from_telegram(@message.from)
    user.increment!(:sessions_completed)

    @session[:mode]            = mode
    @session[:reviewed_count]  = 0
    @session[:session_results] = []
    @session[:queue]           = WordReview.queue_for_user(user, group: @session[:word_group])
    show_next_word
  end

  def show_next_word
    queue = @session[:queue] ||= []

    if queue.empty?
      reviewed = @session[:reviewed_count] || 0
      msg = reviewed > 0 ? MSGS[:learn_all_done].call(reviewed) : MSGS[:learn_no_words]
      reply msg, reply_markup: MAIN_KEYBOARD
      clear_session
      return
    end

    review_id = queue.first
    review    = WordReview.find_by(id: review_id)

    # If the review was deleted or snoozed mid-session, skip it cleanly.
    unless review && !review.snoozed
      queue.shift
      show_next_word
      return
    end

    @session[:current_review_id] = review.id
    word      = review.word
    due_count = queue.size

    prompt = if @session[:mode] == 'learn_de_to_native'
               MSGS[:learn_prompt_de_to_ru].call(word.prompt_de)
             else
               MSGS[:learn_prompt_ru_to_de].call(word.prompt_ru)
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
      reply MSGS[:welcome_back].call(user.display_name, VERSION), reply_markup: MAIN_KEYBOARD
      return
    end

    word = review.word
    if @session[:mode] == 'learn_de_to_native'
      expected_alts    = word.alternatives_translation
      expected_display = word.display_translation
    else
      expected_alts    = word.alternatives_de
      expected_display = word.full_german
    end

    case @message.text
    when MSGS[:btn_back]
      show_stats_and_return

    when MSGS[:btn_snooze]
      review.update!(snoozed: true)
      @session[:queue]&.shift
      reply MSGS[:snoozed_done], parse_mode: 'Markdown'
      show_next_word

    when MSGS[:btn_hint]
      @session[:hint_used] = true
      options = hint_options(word, expected_alts)
      reply MSGS[:learn_hint].call(options), parse_mode: 'Markdown'

    when MSGS[:btn_skip]
      user = User.find_or_create_from_telegram(@message.from)
      SpacedRepetition.update(review, 0, user.sessions_completed)
      record_result(word, 0)
      @session[:reviewed_count] = (@session[:reviewed_count] || 0) + 1
      reinsert_or_advance(0)
      reply "#{MSGS[:feedback_empty]}\n#{MSGS[:learn_correct_answer].call(expected_display)}",
            parse_mode: 'Markdown',
            reply_markup: LearningHandler.report_button(review.id)
      show_next_word

    else
      raw_score  = AnswerScorer.score(expected: expected_alts, given: @message.text)
      hint_used  = @session.delete(:hint_used)
      score      = hint_used ? (raw_score * 0.5).round : raw_score
      user       = User.find_or_create_from_telegram(@message.from)
      SpacedRepetition.update(review, score, user.sessions_completed)
      record_result(word, score)
      @session[:reviewed_count] = (@session[:reviewed_count] || 0) + 1
      reinsert_or_advance(score)

      text = feedback_for(raw_score)
      text += "\n#{MSGS[:hint_penalty]}" if hint_used
      text += "\n#{MSGS[:learn_correct_answer].call(expected_display)}" if raw_score < 100
      reply text, parse_mode: 'Markdown', reply_markup: LearningHandler.report_button(review.id)
      show_next_word
    end
  end

  def handle_report_mistake(review_id)
    target_review = WordReview.find_by(id: review_id)
    return unless target_review

    @session[:scene]           = :edit_word
    @session[:scene_step]      = :fix_de
    @session[:edit_review_id]  = review_id
    @session[:edit_saved_mode] = @session[:mode]
    @session[:mode]            = nil

    word = target_review.word
    reply MSGS[:edit_fix_de].call(word.alternatives_de.join(', ')),
          parse_mode: 'Markdown',
          reply_markup: yes_no_keyboard
  end

  private

  # Remove the current word from the front of the queue, then re-insert it
  # at the appropriate position if the score warrants it.
  def reinsert_or_advance(score)
    queue = @session[:queue] ||= []
    queue.shift   # remove current word from front

    position = REINSERT_POSITIONS.find { |range, _| range.cover?(score) }&.last
    return unless position

    insert_at = [position, queue.size].min
    queue.insert(insert_at, @session[:current_review_id])
  end

  def record_result(word, score)
    @session[:session_results] ||= []
    @session[:session_results] << { word: word.full_german, ru: word.ru, score: score }
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
    @session[:queue]             = nil
  end

  def hint_options(word, correct_alts)
    correct = correct_alts.first

    distractors = if @session[:mode] == 'learn_de_to_native'
                    Word.where.not(ru_normalized: word.ru_normalized)
                        .pluck(:ru)
                  else
                    Word.where.not(de_normalized: word.de_normalized)
                        .map { |w| w.full_german }
                  end

    (distractors.sample(3) + [correct]).shuffle
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

  def yes_no_keyboard
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [[MSGS[:btn_correct], MSGS[:btn_next]]],
      resize_keyboard: true,
      one_time_keyboard: true
    )
  end

  def reply(text, **opts)
    @bot.api.send_message(chat_id: @chat_id, text: text, **opts)
  end
end

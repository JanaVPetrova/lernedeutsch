class LearningHandler
  def initialize(bot, message, session)
    @bot     = bot
    @message = message
    @session = session
    @chat_id = message.chat.id
  end

  def start(mode)
    @session[:mode]           = mode
    @session[:reviewed_count] = 0
    show_next_word
  end

  def show_next_word
    user   = User.find_or_create_from_telegram(@message.from)
    review = WordReview.next_for_user(user)

    unless review
      reviewed = @session[:reviewed_count] || 0
      if reviewed > 0
        reply "All done! You reviewed #{reviewed} word#{reviewed == 1 ? '' : 's'} today. Great work! 🎉",
              reply_markup: MAIN_KEYBOARD
      else
        reply "No words are due for review right now. Come back later! ⏰",
              reply_markup: MAIN_KEYBOARD
      end
      @session[:mode]              = nil
      @session[:current_review_id] = nil
      return
    end

    @session[:current_review_id] = review.id
    word      = review.word
    mode      = @session[:mode]
    due_count = WordReview.for_user(user).due.count

    prompt = if mode == 'learn_de_to_native'
               "Translate to your language:\n\n*#{word.full_german}*"
             else
               "Translate to German:\n\n*#{word.translation}*"
             end

    reply "#{due_count} word#{due_count == 1 ? '' : 's'} left  |  /stop to quit\n\n#{prompt}",
          parse_mode: 'Markdown'
  end

  def handle_answer
    review = WordReview.find_by(id: @session[:current_review_id])
    unless review
      @session[:mode] = nil
      user = User.find_or_create_from_telegram(@message.from)
      reply "Welcome back, #{user.display_name}! Choose what to do:", reply_markup: MAIN_KEYBOARD
      return
    end

    word     = review.word
    mode     = @session[:mode]
    expected = mode == 'learn_de_to_native' ? word.translation : word.full_german
    score    = AnswerScorer.score(expected: expected, given: @message.text)

    SpacedRepetition.update(review, score)
    @session[:reviewed_count] = (@session[:reviewed_count] || 0) + 1

    emoji, label = feedback_for(score)
    reply "#{emoji} #{label}\nCorrect answer: *#{expected}*", parse_mode: 'Markdown'
    show_next_word
  end

  private

  def feedback_for(score)
    case score
    when 100    then ['🎉', 'Perfect!']
    when 75..99 then ['👍', "Almost! (#{score}%)"]
    when 50..74 then ['⚠️',  "Partially correct (#{score}%)"]
    when 1..49  then ['❌', "Incorrect (#{score}%)"]
    else             ['❌', 'No answer']
    end
  end

  def reply(text, **opts)
    @bot.api.send_message(chat_id: @chat_id, text: text, **opts)
  end
end

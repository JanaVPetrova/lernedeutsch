require 'telegem'
require_relative 'lib/boot'

TOKEN = ENV.fetch('TELEGRAM_BOT_TOKEN') { raise 'TELEGRAM_BOT_TOKEN is not set' }

bot = Telegem.new(TOKEN)

# ── Keyboard ─────────────────────────────────────────────────────────────────

MAIN_KEYBOARD = Telegem.keyboard do
  row 'German → Translation', 'Translation → German'
  row 'Upload Words', 'Set Reminder'
end.resize

# ── Helpers ───────────────────────────────────────────────────────────────────

def show_main_menu(ctx)
  user = User.find_or_create_from_telegram(ctx.from)
  ctx.reply "Welcome back, #{user.display_name}! Choose what to do:", reply_markup: MAIN_KEYBOARD
end

def start_learning(ctx, mode)
  ctx.session[:mode]           = mode
  ctx.session[:reviewed_count] = 0
  show_next_word(ctx)
end

def show_next_word(ctx)
  user   = User.find_or_create_from_telegram(ctx.from)
  review = WordReview.next_for_user(user)

  unless review
    reviewed = ctx.session[:reviewed_count] || 0
    if reviewed > 0
      ctx.reply "All done! You reviewed #{reviewed} word#{reviewed == 1 ? '' : 's'} today. Great work! 🎉",
                reply_markup: MAIN_KEYBOARD
    else
      ctx.reply "No words are due for review right now. Come back later! ⏰",
                reply_markup: MAIN_KEYBOARD
    end
    ctx.session[:mode]              = nil
    ctx.session[:current_review_id] = nil
    return
  end

  ctx.session[:current_review_id] = review.id
  word      = review.word
  mode      = ctx.session[:mode]
  due_count = WordReview.for_user(user).due.count

  prompt = if mode == 'learn_de_to_native'
             "Translate to your language:\n\n*#{word.full_german}*"
           else
             "Translate to German:\n\n*#{word.translation}*"
           end

  ctx.reply "#{due_count} word#{due_count == 1 ? '' : 's'} left  |  /stop to quit\n\n#{prompt}",
            parse_mode: 'Markdown'
end

def handle_learning_answer(ctx)
  review = WordReview.find_by(id: ctx.session[:current_review_id])
  unless review
    ctx.session[:mode] = nil
    show_main_menu(ctx)
    return
  end

  word     = review.word
  mode     = ctx.session[:mode]
  expected = mode == 'learn_de_to_native' ? word.translation : word.full_german
  score    = AnswerScorer.score(expected: expected, given: ctx.message.text)

  SpacedRepetition.update(review, score)
  ctx.session[:reviewed_count] = (ctx.session[:reviewed_count] || 0) + 1

  emoji, label = case score
                 when 100    then ['🎉', 'Perfect!']
                 when 75..99 then ['👍', "Almost! (#{score}%)"]
                 when 50..74 then ['⚠️',  "Partially correct (#{score}%)"]
                 when 1..49  then ['❌', "Incorrect (#{score}%)"]
                 else             ['❌', 'No answer']
                 end

  ctx.reply "#{emoji} #{label}\nCorrect answer: *#{expected}*", parse_mode: 'Markdown'
  show_next_word(ctx)
end

# ── Scenes ────────────────────────────────────────────────────────────────────

# Scene: upload_words
# Step 1 – prompt user for a file or pasted text.
# Step 2 – receive content, parse, and persist.
bot.scene :upload_words do
  step :prompt do |ctx|
    ctx.reply <<~TEXT, parse_mode: 'Markdown'
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

  step :process do |ctx|
    user    = User.find_or_create_from_telegram(ctx.from)
    content = nil

    if ctx.message.document
      file_id = ctx.message.document.file_id
      content = WordImporter.download_document(file_id, TOKEN)
    elsif ctx.message.text
      content = ctx.message.text
    end

    if content.nil? || content.strip.empty?
      ctx.reply "Couldn't read that. Please send a .csv/.txt file or paste your words directly."
      ctx.leave_scene
      next
    end

    words_data = WordImporter.parse(content)
    if words_data.empty?
      ctx.reply "No valid word pairs found. Check the format (german,translation) and try again."
      ctx.leave_scene
      next
    end

    count = WordImporter.import(user, words_data)
    skipped = words_data.length - count
    msg = "✅ Added *#{count}* new word#{count == 1 ? '' : 's'}!"
    msg += "\n_(#{skipped} already existed and were skipped)_" if skipped > 0
    ctx.reply msg, parse_mode: 'Markdown', reply_markup: MAIN_KEYBOARD
    ctx.leave_scene
  end
end

# Scene: set_reminder
# Step 1 – ask for time.
# Step 2 – ask for days.
# Step 3 – save and confirm.
bot.scene :set_reminder do
  step :ask_time do |ctx|
    ctx.reply "At what time should I remind you to study?\n\nPlease reply in *HH:MM* format (e.g. _09:00_ or _18:30_).",
              parse_mode: 'Markdown'
  end

  step :ask_days do |ctx|
    time = ctx.message.text.strip
    unless time.match?(/\A\d{2}:\d{2}\z/)
      ctx.reply "That doesn't look like a valid time. Please use HH:MM (e.g. 09:00)."
      ctx.leave_scene
      next
    end

    ctx.session[:reminder_time] = time
    ctx.reply "Great! Which days?\n\nType *all*, *weekdays*, *weekend*, or list specific days like _mon,wed,fri_.",
              parse_mode: 'Markdown'
  end

  step :save do |ctx|
    user        = User.find_or_create_from_telegram(ctx.from)
    time        = ctx.session[:reminder_time]
    days_input  = ctx.message.text.strip.downcase

    days = case days_input
           when 'all'      then Reminder::ALL_DAYS.dup
           when 'weekdays' then %w[mon tue wed thu fri]
           when 'weekend'  then %w[sat sun]
           else
             days_input.split(',').map(&:strip).select { |d| Reminder::ALL_DAYS.include?(d) }
           end

    if days.empty?
      ctx.reply "I didn't recognise those days. Use: all, weekdays, weekend, or specific abbreviations like mon,tue,wed."
      ctx.leave_scene
      next
    end

    reminder = Reminder.find_or_initialize_by(user: user)
    reminder.update!(time: time, days: days, enabled: true)

    days_str = days_input == 'all' ? 'every day' : days.join(', ')
    ctx.reply "✅ Reminder set for *#{time}* on #{days_str}!", parse_mode: 'Markdown',
              reply_markup: MAIN_KEYBOARD
    ctx.leave_scene
  end
end

# ── Middleware ────────────────────────────────────────────────────────────────

class UserRegistrationMiddleware
  def call(ctx, next_middleware)
    User.find_or_create_from_telegram(ctx.from) if ctx.from
    next_middleware.call(ctx)
  end
end

bot.use UserRegistrationMiddleware.new

# ── Commands ──────────────────────────────────────────────────────────────────

bot.command 'start' do |ctx|
  ctx.session[:mode]              = nil
  ctx.session[:current_review_id] = nil
  user = User.find_or_create_from_telegram(ctx.from)
  ctx.reply "👋 Hallo, #{user.display_name}! Let's learn some German.", reply_markup: MAIN_KEYBOARD
end

bot.command 'stop' do |ctx|
  ctx.session[:mode]              = nil
  ctx.session[:current_review_id] = nil
  show_main_menu(ctx)
end

bot.command 'upload' do |ctx|
  ctx.enter_scene(:upload_words)
end

bot.command 'reminder' do |ctx|
  ctx.enter_scene(:set_reminder)
end

# ── Message Handler ───────────────────────────────────────────────────────────

bot.on :message do |ctx|
  next unless ctx.message.text

  if ctx.session[:mode]
    handle_learning_answer(ctx)
  else
    case ctx.message.text
    when 'German → Translation' then start_learning(ctx, 'learn_de_to_native')
    when 'Translation → German' then start_learning(ctx, 'learn_native_to_de')
    when 'Upload Words'         then ctx.enter_scene(:upload_words)
    when 'Set Reminder'         then ctx.enter_scene(:set_reminder)
    end
  end
end

# ── Start ─────────────────────────────────────────────────────────────────────

ReminderScheduler.start(TOKEN)
bot.start_polling

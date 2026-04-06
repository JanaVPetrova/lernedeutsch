require 'spec_helper'

# ── E2E bootstrap ─────────────────────────────────────────────────────────────
#
# We load bot.rb once with Telegram::Bot::Client stubbed so it doesn't start
# a real polling loop. The message-handler block is captured in LISTEN_BLOCK
# and invoked directly by each test.
# ─────────────────────────────────────────────────────────────────────────────

ENV['TELEGRAM_BOT_TOKEN'] ||= 'test_token_e2e'

# No-op the background scheduler thread so it doesn't try to hit the real API.
ReminderScheduler.define_singleton_method(:start) { |_| }

module BotE2EHelper
  LISTEN_BLOCK  = [nil]
  SENT_MESSAGES = []

  class FakeApi
    def send_message(**args)
      BotE2EHelper::SENT_MESSAGES << args
      args
    end

    def answer_callback_query(**); end
  end

  FAKE_API = FakeApi.new

  class FakeBot
    def api = BotE2EHelper::FAKE_API

    def listen(&block)
      BotE2EHelper::LISTEN_BLOCK[0] = block
    end
  end
end

# Patch Client.run to yield a FakeBot instead of starting the real polling loop.
module Telegram
  module Bot
    class Client
      def self.run(_token)
        yield BotE2EHelper::FakeBot.new
      end
    end
  end
end

# bot.rb redefines MAIN_KEYBOARD; remove the spec_helper stub first to avoid
# the "already initialized constant" warning.
Object.send(:remove_const, :MAIN_KEYBOARD) if defined?(MAIN_KEYBOARD)

# Load bot.rb (once). It defines SESSIONS, LOGGER, MAIN_KEYBOARD at top level
# and immediately calls Client.run, which triggers our stub above.
load File.expand_path('../../bot.rb', __dir__)

# ── Helpers ───────────────────────────────────────────────────────────────────

module BotE2EHelper
  # Build a real Telegram::Bot::Types::Message from a plain hash.
  def tg_message(user_attrs, text: nil)
    Telegram::Bot::Types::Message.new(
      message_id: rand(100_000),
      date:       Time.now.to_i,
      chat:       { id: user_attrs[:id], type: 'private' },
      from:       user_attrs,
      text:       text
    )
  end

  # Dispatch a message through the bot's handler and return only the messages
  # sent during that single dispatch.
  def receive(user_attrs, text: nil)
    before = BotE2EHelper::SENT_MESSAGES.size
    BotE2EHelper::LISTEN_BLOCK[0].call(tg_message(user_attrs, text: text))
    BotE2EHelper::SENT_MESSAGES[before..]
  end

  def last_text(user_attrs, text: nil)
    receive(user_attrs, text: text).last&.dig(:text)
  end
end

# ── Shared setup ──────────────────────────────────────────────────────────────

RSpec.describe 'Bot user stories', type: :e2e do
  include BotE2EHelper
  include FactoryBot::Syntax::Methods

  # Bot-level state lives in SESSIONS (defined by bot.rb).
  before { SESSIONS.clear }
  after  { BotE2EHelper::SENT_MESSAGES.clear }

  # A reusable Telegram identity hash (mimics message.from attributes).
  let(:tg_user) do
    { id: 999_001, first_name: 'Anya', last_name: 'Test', username: 'anya_test', is_bot: false }
  end

  # ── Story 1: new user registration ──────────────────────────────────────────

  describe 'new user sends /start' do
    it 'creates the user in the database' do
      expect { receive(tg_user, text: '/start') }
        .to change(User, :count).by(1)
    end

    it 'sends the welcome greeting with the user name' do
      msgs = receive(tg_user, text: '/start')
      expect(msgs.last[:text]).to include('Anya')
    end

    it 'does not create a duplicate user on a second /start' do
      receive(tg_user, text: '/start')
      expect { receive(tg_user, text: '/start') }.not_to change(User, :count)
    end
  end

  # ── Story 2: upload a new word group ────────────────────────────────────────

  describe 'user uploads a new word group' do
    before { receive(tg_user, text: '/start') }

    it 'walks the full upload flow and persists words' do
      # Step 1 – tap the upload button
      msgs = receive(tg_user, text: MSGS[:btn_upload])
      expect(msgs.last[:text]).to include(MSGS[:upload_ask_name_ru])

      # Step 2 – provide the Russian group name
      msgs = receive(tg_user, text: 'Животные')
      expect(msgs.last[:text]).to include(MSGS[:upload_ask_name_de])

      # Step 3 – provide the German group name
      msgs = receive(tg_user, text: 'Tiere')
      expect(msgs.last[:text]).to include('Tiere')  # upload prompt mentions the group

      # Step 4 – send the word list
      words_tsv = "der Hund\tdog\ndie Katze\tcat\ndas Pferd\thorse"
      expect {
        msgs = receive(tg_user, text: words_tsv)
      }.to change(Word, :count).by(3)
        .and change(WordGroup, :count).by(1)

      expect(msgs.last[:text]).to include('3')
      expect(msgs.last[:text]).to include('Животные')
    end

    it 'creates the word group with both names' do
      receive(tg_user, text: MSGS[:btn_upload])
      receive(tg_user, text: 'Еда')
      receive(tg_user, text: 'Essen')
      receive(tg_user, text: "das Brot\tbread")

      group = WordGroup.find_by(name_ru: 'Еда')
      expect(group).to be_present
      expect(group.name_de).to eq('Essen')
    end
  end

  # ── Story 3: upload to an existing group ────────────────────────────────────

  describe 'user uploads to an existing group' do
    let!(:group) { create(:word_group, name_ru: 'Цвета', name_de: 'Farben') }

    before { receive(tg_user, text: '/start') }

    it 'offers the existing group as an option and adds words to it' do
      msgs = receive(tg_user, text: MSGS[:btn_upload])
      expect(msgs.last[:text]).to eq(MSGS[:upload_pick_group])

      receive(tg_user, text: 'Цвета / Farben')

      expect {
        receive(tg_user, text: "rot\tred\nblau\tblue")
      }.to change { group.words.count }.by(2)
    end
  end

  # ── Story 4: learning session – German → Translation ────────────────────────

  describe 'learning session (German → Translation)' do
    let!(:group) { create(:word_group) }
    let!(:word)  { create(:word, de: 'Hund', article_de: 'der', ru: 'dog', word_group: group) }

    before { receive(tg_user, text: '/start') }

    it 'shows a word prompt after the user picks a group' do
      receive(tg_user, text: MSGS[:btn_de_to_ru])
      msgs = receive(tg_user, text: MSGS[:btn_all_words])
      expect(msgs.last[:text]).to include('der Hund')
    end

    it 'accepts a correct answer and records a perfect score' do
      receive(tg_user, text: MSGS[:btn_de_to_ru])
      receive(tg_user, text: MSGS[:btn_all_words])  # word prompt shown

      msgs = receive(tg_user, text: 'dog')
      expect(msgs.first[:text]).to include('🎉')
      expect(word.word_reviews.first.last_score).to eq(100)
    end

    it 'shows feedback and correct answer on a wrong answer' do
      receive(tg_user, text: MSGS[:btn_de_to_ru])
      receive(tg_user, text: MSGS[:btn_all_words])

      msgs = receive(tg_user, text: 'xyz')
      expect(msgs.first[:text]).to include('❌')
      expect(msgs.first[:text]).to include(MSGS[:learn_correct_answer].call('dog'))
    end

    it 'shows "all done" and session stats when all words are answered' do
      receive(tg_user, text: MSGS[:btn_de_to_ru])
      receive(tg_user, text: MSGS[:btn_all_words])
      receive(tg_user, text: 'dog')  # answer (triggers "all done" since only 1 word)

      msgs = BotE2EHelper::SENT_MESSAGES
      all_done = msgs.find { |m| m[:text]&.include?(MSGS[:learn_all_done].call(1)) }
      expect(all_done).to be_present
    end

    it 'returns to the main keyboard after pressing Back' do
      receive(tg_user, text: MSGS[:btn_de_to_ru])
      receive(tg_user, text: MSGS[:btn_all_words])

      msgs = receive(tg_user, text: MSGS[:btn_back])
      expect(msgs.last[:reply_markup]).to eq(MAIN_KEYBOARD)
    end
  end

  # ── Story 5: learning session – Translation → German ────────────────────────

  describe 'learning session (Translation → German)' do
    let!(:word) { create(:word, de: 'Katze', article_de: nil, ru: 'cat') }

    before { receive(tg_user, text: '/start') }

    it 'prompts with the translation and accepts the German word' do
      receive(tg_user, text: MSGS[:btn_ru_to_de])
      msgs = receive(tg_user, text: MSGS[:btn_all_words])
      expect(msgs.last[:text]).to include('cat')

      msgs = receive(tg_user, text: 'Katze')
      expect(msgs.first[:text]).to include('🎉')
    end

    it 'requires the correct article for nouns' do
      word.update!(de: 'Hund', article_de: 'der', ru: 'dog')
      receive(tg_user, text: MSGS[:btn_ru_to_de])
      receive(tg_user, text: MSGS[:btn_all_words])

      msgs = receive(tg_user, text: 'Hund')  # missing article
      expect(msgs.first[:text]).not_to include('🎉')  # not perfect
    end
  end

  # ── Story 6: skip a word during practice ────────────────────────────────────

  describe 'user skips a word during practice' do
    let!(:word) { create(:word, de: 'Apfel', ru: 'apple') }

    before do
      receive(tg_user, text: '/start')
      receive(tg_user, text: MSGS[:btn_de_to_ru])
      receive(tg_user, text: MSGS[:btn_all_words])
    end

    it 'records a score of 0 for the skipped word' do
      receive(tg_user, text: MSGS[:btn_skip])
      review = word.word_reviews.first
      expect(review.last_score).to eq(0)
    end

    it 'shows the correct answer after skipping' do
      msgs = receive(tg_user, text: MSGS[:btn_skip])
      expect(msgs.first[:text]).to include(MSGS[:feedback_empty])
      expect(msgs.first[:text]).to include('apple')
    end

    it 'shows skip count in session stats when backing out' do
      receive(tg_user, text: MSGS[:btn_skip])
      msgs = receive(tg_user, text: MSGS[:btn_back])
      expect(msgs.last[:text]).to include('⏭')
    end
  end

  # ── Story 7: snooze a word and manage the stop-list ─────────────────────────

  describe 'user snoozed a word and manages the stop-list' do
    let!(:word) { create(:word, de: 'Buch', article_de: 'das', ru: 'book') }

    before do
      receive(tg_user, text: '/start')
      receive(tg_user, text: MSGS[:btn_de_to_ru])
      receive(tg_user, text: MSGS[:btn_all_words])
    end

    it 'marks the word as snoozed in the database' do
      receive(tg_user, text: MSGS[:btn_snooze])
      review = word.word_reviews.first
      expect(review).to be_snoozed
    end

    it 'shows the snoozed word in the stop-list' do
      receive(tg_user, text: MSGS[:btn_snooze])

      # Go back to main menu and open the stop-list
      receive(tg_user, text: MSGS[:btn_back])
      msgs = receive(tg_user, text: MSGS[:btn_snoozed])
      expect(msgs.last[:text]).to include(MSGS[:snoozed_list_header])
    end

    it 'restores a word from the stop-list' do
      receive(tg_user, text: MSGS[:btn_snooze])
      receive(tg_user, text: MSGS[:btn_back])
      receive(tg_user, text: MSGS[:btn_snoozed])

      msgs = receive(tg_user, text: 'das Buch')
      expect(msgs.first[:text]).to include(MSGS[:unsnoozed_done].call('das Buch'))
      expect(word.word_reviews.first.reload).not_to be_snoozed
    end
  end

  # ── Story 8: global statistics ───────────────────────────────────────────────

  describe 'global statistics' do
    let!(:group) { create(:word_group, name_ru: 'Животные', name_de: 'Tiere') }
    let!(:word)  { create(:word, de: 'Hund', ru: 'dog', word_group: group) }

    before { receive(tg_user, text: '/start') }

    it 'shows "no data" message when no words exist' do
      Word.destroy_all
      msgs = receive(tg_user, text: MSGS[:btn_stats])
      expect(msgs.last[:text]).to eq(MSGS[:stats_no_data])
    end

    it 'shows group stats with unreviewed count when words exist but none practised' do
      msgs = receive(tg_user, text: MSGS[:btn_stats])
      expect(msgs.last[:text]).to include('Животные')
      expect(msgs.last[:text]).to include('Tiere')
      expect(msgs.last[:text]).to include('○ Не изучено: 1')
    end

    it 'reflects progress in box 2 after answering correctly once' do
      receive(tg_user, text: MSGS[:btn_de_to_ru])
      receive(tg_user, text: MSGS[:btn_all_words])
      receive(tg_user, text: 'dog')

      msgs = receive(tg_user, text: MSGS[:btn_stats])
      expect(msgs.last[:text]).to include('📖 Начало: 1')
    end
  end

  # ── Story 9: set a reminder ──────────────────────────────────────────────────

  describe 'user sets a daily reminder' do
    before { receive(tg_user, text: '/start') }

    it 'saves the reminder after providing time and days' do
      user = User.find_by(telegram_id: tg_user[:id])

      receive(tg_user, text: MSGS[:btn_reminder])
      receive(tg_user, text: '09:00')

      expect {
        receive(tg_user, text: 'все')
      }.to change(Reminder, :count).by(1)

      reminder = Reminder.find_by(user: user)
      expect(reminder.time).to eq('09:00')
      expect(reminder.days.length).to eq(7)
    end

    it 'sends confirmation with the set time' do
      receive(tg_user, text: MSGS[:btn_reminder])
      receive(tg_user, text: '18:30')
      msgs = receive(tg_user, text: 'будни')
      expect(msgs.last[:text]).to include('18:30')
    end

    it 'rejects an invalid time format' do
      receive(tg_user, text: MSGS[:btn_reminder])
      msgs = receive(tg_user, text: 'nine o clock')
      expect(msgs.last[:text]).to eq(MSGS[:reminder_bad_time])
    end

    it 'rejects invalid days' do
      receive(tg_user, text: MSGS[:btn_reminder])
      receive(tg_user, text: '10:00')
      msgs = receive(tg_user, text: 'whenever')
      expect(msgs.last[:text]).to eq(MSGS[:reminder_bad_days])
    end

    it 'updates an existing reminder instead of creating a duplicate' do
      receive(tg_user, text: MSGS[:btn_reminder])
      receive(tg_user, text: '08:00')
      receive(tg_user, text: 'все')

      receive(tg_user, text: MSGS[:btn_reminder])
      receive(tg_user, text: '20:00')

      expect {
        receive(tg_user, text: 'выходные')
      }.not_to change(Reminder, :count)

      user = User.find_by(telegram_id: tg_user[:id])
      expect(Reminder.find_by(user: user).time).to eq('20:00')
    end
  end
end

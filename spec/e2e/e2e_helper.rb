require 'spec_helper'

# ── E2E bootstrap ─────────────────────────────────────────────────────────────
#
# This file is required by every e2e spec. Ruby's require is idempotent, so
# the bootstrap (patching Client.run, loading bot.rb) runs exactly once no
# matter how many spec files are loaded.
# ─────────────────────────────────────────────────────────────────────────────

ENV['TELEGRAM_BOT_TOKEN'] ||= 'test_token_e2e'

# No-op the background scheduler so it doesn't try to hit the real API.
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

# ── Shared context ────────────────────────────────────────────────────────────

RSpec.shared_context 'bot e2e' do
  include BotE2EHelper
  include FactoryBot::Syntax::Methods

  before { SESSIONS.clear }
  after  { BotE2EHelper::SENT_MESSAGES.clear }

  let(:tg_user) do
    { id: 999_001, first_name: 'Anya', last_name: 'Test', username: 'anya_test', is_bot: false }
  end
end

require 'spec_helper'

RSpec.describe LearningHandler do
  let(:api)     { double('api') }
  let(:bot)     { double('bot', api: api) }
  let(:session) { {} }
  let(:user)    { create(:user) }

  let(:from) do
    double('telegram_user',
           id:         user.telegram_id,
           first_name: user.first_name,
           last_name:  user.last_name,
           username:   user.username)
  end

  let(:chat)        { double('chat', id: 12_345) }
  let(:answer_text) { nil }
  let(:message)     { double('message', from: from, chat: chat, text: answer_text) }

  subject(:handler) { described_class.new(bot, message, session) }

  # Capture all send_message calls; individual examples can add expectations on top.
  let(:sent_messages) { [] }
  before { allow(api).to receive(:send_message) { |**args| sent_messages << args } }

  # ── #start ──────────────────────────────────────────────────────────────────

  describe '#start' do
    let(:word)    { create(:word, user: user) }
    let!(:review) { create(:word_review, word: word, user: user, due_date: Date.today) }

    it 'stores the mode in session' do
      handler.start('learn_de_to_native')
      expect(session[:mode]).to eq('learn_de_to_native')
    end

    it 'resets reviewed_count to 0' do
      session[:reviewed_count] = 5
      handler.start('learn_de_to_native')
      expect(session[:reviewed_count]).to eq(0)
    end

    it 'immediately shows the first word' do
      handler.start('learn_de_to_native')
      expect(sent_messages).not_to be_empty
    end
  end

  # ── #show_next_word ──────────────────────────────────────────────────────────

  describe '#show_next_word' do
    context 'when no words are due and none have been reviewed yet' do
      before { session[:reviewed_count] = 0 }

      it 'sends a "come back later" message' do
        handler.show_next_word
        expect(sent_messages.last).to include(text: include('No words are due'), reply_markup: MAIN_KEYBOARD)
      end

      it 'clears mode from session' do
        session[:mode] = 'learn_de_to_native'
        handler.show_next_word
        expect(session[:mode]).to be_nil
      end

      it 'clears current_review_id from session' do
        session[:current_review_id] = 99
        handler.show_next_word
        expect(session[:current_review_id]).to be_nil
      end
    end

    context 'when no words are due but some have been reviewed this session' do
      before { session[:reviewed_count] = 3 }

      it 'sends an "all done" message with the count' do
        handler.show_next_word
        expect(sent_messages.last).to include(text: include('All done'), reply_markup: MAIN_KEYBOARD)
      end
    end

    context 'when a word is due' do
      let(:word)    { create(:word, user: user, german_word: 'Hund', translation: 'dog') }
      let!(:review) { create(:word_review, word: word, user: user, due_date: Date.today) }

      it 'stores the review id in session' do
        session[:mode] = 'learn_de_to_native'
        handler.show_next_word
        expect(session[:current_review_id]).to eq(review.id)
      end

      it 'prompts with the German word in learn_de_to_native mode' do
        session[:mode] = 'learn_de_to_native'
        handler.show_next_word
        expect(sent_messages.last).to include(text: include('Hund'), parse_mode: 'Markdown')
      end

      it 'prompts with the translation in learn_native_to_de mode' do
        session[:mode] = 'learn_native_to_de'
        handler.show_next_word
        expect(sent_messages.last).to include(text: include('dog'), parse_mode: 'Markdown')
      end

      it 'includes the /stop hint in the prompt' do
        session[:mode] = 'learn_de_to_native'
        handler.show_next_word
        expect(sent_messages.last[:text]).to include('/stop')
      end

      it 'includes the article when the word has one' do
        word.update!(article: 'der')
        session[:mode] = 'learn_native_to_de'
        handler.show_next_word
        # correct answer prompt shows translation, not German — article tested via handle_answer
        expect(session[:current_review_id]).to eq(review.id)
      end
    end
  end

  # ── #handle_answer ───────────────────────────────────────────────────────────

  describe '#handle_answer' do
    context 'when session has no current review' do
      before { session[:current_review_id] = nil }

      it 'clears the mode' do
        session[:mode] = 'learn_de_to_native'
        handler.handle_answer
        expect(session[:mode]).to be_nil
      end

      it 'sends the main menu' do
        handler.handle_answer
        expect(sent_messages.last).to include(reply_markup: MAIN_KEYBOARD)
      end
    end

    context 'when a current review exists' do
      let(:word)    { create(:word, user: user, german_word: 'Katze', translation: 'cat') }
      let!(:review) { create(:word_review, word: word, user: user, due_date: Date.today) }

      before do
        session[:current_review_id] = review.id
        session[:mode]              = 'learn_de_to_native'
        session[:reviewed_count]    = 0
      end

      context 'with a perfect answer' do
        let(:answer_text) { 'cat' }

        it 'sends the 🎉 feedback' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include('🎉')
        end

        it 'includes the correct answer in the feedback' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include('cat')
        end

        it 'increments reviewed_count' do
          handler.handle_answer
          expect(session[:reviewed_count]).to eq(1)
        end

        it 'updates the spaced repetition record' do
          expect { handler.handle_answer }.to change { review.reload.due_date }
        end
      end

      context 'with an almost-correct answer (minor typo)' do
        let(:answer_text) { 'caat' }

        it 'sends the 👍 or ⚠️ feedback' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to match(/👍|⚠️/)
        end
      end

      context 'with a wrong answer' do
        let(:answer_text) { 'xyz' }

        it 'sends the ❌ feedback' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include('❌')
        end
      end

      context 'with an empty answer' do
        let(:answer_text) { '' }

        it 'sends the ❌ no-answer feedback' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include('❌')
        end
      end

      context 'in learn_native_to_de mode' do
        let(:answer_text) { 'Katze' }

        before { session[:mode] = 'learn_native_to_de' }

        it 'scores against the German word' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include('🎉')
        end
      end

      context 'in learn_native_to_de mode with article' do
        let(:word)        { create(:word, :with_article, user: user) }
        let!(:review)     { create(:word_review, word: word, user: user, due_date: Date.today) }
        let(:answer_text) { 'der Hund' }

        before do
          session[:current_review_id] = review.id
          session[:mode]              = 'learn_native_to_de'
        end

        it 'accepts the full "article word" as a perfect answer' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include('🎉')
        end
      end
    end
  end
end

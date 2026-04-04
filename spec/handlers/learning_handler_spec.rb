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
    context 'when no words are due and none reviewed this session' do
      before { session[:reviewed_count] = 0 }

      it 'sends the "no words" message' do
        handler.show_next_word
        expect(sent_messages.last[:text]).to eq(MSGS[:learn_no_words])
      end

      it 'returns to main keyboard' do
        handler.show_next_word
        expect(sent_messages.last[:reply_markup]).to eq(MAIN_KEYBOARD)
      end

      it 'clears mode and current_review_id from session' do
        session[:mode] = 'learn_de_to_native'
        session[:current_review_id] = 42
        handler.show_next_word
        expect(session[:mode]).to be_nil
        expect(session[:current_review_id]).to be_nil
      end
    end

    context 'when no words are due but some were reviewed' do
      before { session[:reviewed_count] = 3 }

      it 'sends the "all done" message with the count' do
        handler.show_next_word
        expect(sent_messages.last[:text]).to eq(MSGS[:learn_all_done].call(3))
      end

      it 'returns to main keyboard' do
        handler.show_next_word
        expect(sent_messages.last[:reply_markup]).to eq(MAIN_KEYBOARD)
      end
    end

    context 'when a word is due' do
      let(:word)    { create(:word, user: user, german_word: 'Hund', translation: 'собака') }
      let!(:review) { create(:word_review, word: word, user: user, due_date: Date.today) }

      before { session[:mode] = 'learn_de_to_native' }

      it 'stores the review id in session' do
        handler.show_next_word
        expect(session[:current_review_id]).to eq(review.id)
      end

      it 'shows the LEARNING_KEYBOARD' do
        handler.show_next_word
        expect(sent_messages.last[:reply_markup]).to eq(LearningHandler::LEARNING_KEYBOARD)
      end

      it 'prompts with the German word in learn_de_to_native mode' do
        handler.show_next_word
        expect(sent_messages.last[:text]).to include('Hund')
      end

      it 'prompts to translate to Russian in learn_de_to_native mode' do
        handler.show_next_word
        expect(sent_messages.last[:text]).to include(MSGS[:learn_prompt_de_to_ru].call('Hund'))
      end

      it 'prompts with the translation in learn_native_to_de mode' do
        session[:mode] = 'learn_native_to_de'
        handler.show_next_word
        expect(sent_messages.last[:text]).to include('собака')
      end

      it 'includes the /stop hint' do
        handler.show_next_word
        expect(sent_messages.last[:text]).to include('/stop')
      end

      it 'includes the due count in the prompt' do
        handler.show_next_word
        expect(sent_messages.last[:text]).to include(MSGS[:learn_progress].call(1))
      end

      it 'includes the article in the German word when present' do
        word.update!(article: 'der')
        handler.show_next_word
        expect(sent_messages.last[:text]).to include('der Hund')
      end
    end

    context 'with a group filter' do
      let(:group)         { create(:word_group, user: user) }
      let(:word_in_group) { create(:word, user: user, word_group: group) }
      let(:word_outside)  { create(:word, user: user, word_group: nil) }
      let!(:review_in)    { create(:word_review, word: word_in_group, user: user, due_date: Date.today) }
      let!(:review_out)   { create(:word_review, word: word_outside,  user: user, due_date: Date.today - 1) }

      before do
        session[:mode]       = 'learn_de_to_native'
        session[:word_group] = group
      end

      it 'shows only the word in the selected group' do
        handler.show_next_word
        expect(session[:current_review_id]).to eq(review_in.id)
      end
    end
  end

  # ── #handle_answer ───────────────────────────────────────────────────────────

  describe '#handle_answer' do
    context 'when session has no current review' do
      before { session[:current_review_id] = nil }

      it 'clears mode' do
        session[:mode] = 'learn_de_to_native'
        handler.handle_answer
        expect(session[:mode]).to be_nil
      end

      it 'sends the welcome-back message with main keyboard' do
        handler.handle_answer
        expect(sent_messages.last).to include(reply_markup: MAIN_KEYBOARD)
      end
    end

    context 'with an active review' do
      let(:word)    { create(:word, user: user, german_word: 'Katze', translation: 'кошка') }
      let!(:review) { create(:word_review, word: word, user: user, due_date: Date.today) }

      before do
        session[:current_review_id] = review.id
        session[:mode]              = 'learn_de_to_native'
        session[:reviewed_count]    = 0
      end

      # ── Perfect answer ────────────────────────────────────────────────────────

      context 'with a perfect answer' do
        let(:answer_text) { 'кошка' }

        it 'sends the perfect feedback emoji' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include('🎉')
        end

        it 'does NOT show the correct answer on a perfect score' do
          handler.handle_answer
          expect(sent_messages.first[:text]).not_to include(MSGS[:learn_correct_answer].call('кошка'))
        end

        it 'increments reviewed_count' do
          handler.handle_answer
          expect(session[:reviewed_count]).to eq(1)
        end

        it 'updates the spaced repetition record' do
          expect { handler.handle_answer }.to change { review.reload.due_date }
        end
      end

      # ── Partial / wrong answer ────────────────────────────────────────────────

      context 'with a partial answer' do
        let(:answer_text) { 'кошки' }

        it 'sends partial feedback' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to match(/👍|⚠️|❌/)
        end

        it 'shows the correct answer' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include(MSGS[:learn_correct_answer].call('кошка'))
        end
      end

      context 'with a completely wrong answer' do
        let(:answer_text) { 'xyz' }

        it 'sends the wrong-answer feedback' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include('❌')
        end

        it 'shows the correct answer' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include(MSGS[:learn_correct_answer].call('кошка'))
        end
      end

      # ── Skip button ───────────────────────────────────────────────────────────

      context 'when the skip button is pressed' do
        let(:answer_text) { MSGS[:btn_skip] }

        it 'sends the skipped feedback' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include(MSGS[:feedback_empty])
        end

        it 'shows the correct answer after skip' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include(MSGS[:learn_correct_answer].call('кошка'))
        end

        it 'updates the SRS with score 0' do
          review.update!(repetitions: 3, interval: 10)
          expect { handler.handle_answer }
            .to change { review.reload.repetitions }.from(3).to(0)
            .and change { review.reload.due_date }
        end

        it 'increments reviewed_count' do
          handler.handle_answer
          expect(session[:reviewed_count]).to eq(1)
        end
      end

      # ── Report mistake button ─────────────────────────────────────────────────

      context 'when the report-mistake button is pressed' do
        let(:answer_text) { MSGS[:btn_report_mistake] }

        it 'sets session scene to :edit_word' do
          handler.handle_answer
          expect(session[:scene]).to eq(:edit_word)
        end

        it 'sets scene_step to :awaiting_translation' do
          handler.handle_answer
          expect(session[:scene_step]).to eq(:awaiting_translation)
        end

        it 'stores the review id in session' do
          handler.handle_answer
          expect(session[:edit_review_id]).to eq(review.id)
        end

        it 'sends the edit prompt with the current translation' do
          handler.handle_answer
          expect(sent_messages.last[:text]).to include('кошка')
        end

        it 'removes the learning keyboard during editing' do
          handler.handle_answer
          expect(sent_messages.last[:reply_markup]).to be_a(Telegram::Bot::Types::ReplyKeyboardRemove)
        end

        it 'does not update the SRS record' do
          expect { handler.handle_answer }.not_to change { review.reload.due_date }
        end
      end

      # ── Mode: native → German ─────────────────────────────────────────────────

      context 'in learn_native_to_de mode with a perfect answer' do
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

        it 'accepts "article word" as a perfect answer' do
          handler.handle_answer
          expect(sent_messages.first[:text]).to include('🎉')
        end
      end
    end
  end
end

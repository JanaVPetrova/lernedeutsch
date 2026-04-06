require_relative 'e2e_helper'

RSpec.describe 'Learning: German → Russian', type: :e2e do
  include_context 'bot e2e'

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
    receive(tg_user, text: MSGS[:btn_all_words])

    msgs = receive(tg_user, text: 'dog')
    expect(msgs.first[:text]).to include('🎉')
    expect(word.word_reviews.first.last_score).to eq(100)
  end

  it 'shows feedback and the correct answer on a wrong answer' do
    receive(tg_user, text: MSGS[:btn_de_to_ru])
    receive(tg_user, text: MSGS[:btn_all_words])

    msgs = receive(tg_user, text: 'xyz')
    expect(msgs.first[:text]).to include('❌')
    expect(msgs.first[:text]).to include(MSGS[:learn_correct_answer].call('dog'))
  end

  it 'shows "all done" when all words are answered' do
    receive(tg_user, text: MSGS[:btn_de_to_ru])
    receive(tg_user, text: MSGS[:btn_all_words])
    receive(tg_user, text: 'dog')

    all_done = BotE2EHelper::SENT_MESSAGES.find { |m| m[:text]&.include?(MSGS[:learn_all_done].call(1)) }
    expect(all_done).to be_present
  end

  it 'returns to the main keyboard after pressing Back' do
    receive(tg_user, text: MSGS[:btn_de_to_ru])
    receive(tg_user, text: MSGS[:btn_all_words])

    msgs = receive(tg_user, text: MSGS[:btn_back])
    expect(msgs.last[:reply_markup]).to eq(MAIN_KEYBOARD)
  end
end

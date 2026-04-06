require_relative 'e2e_helper'

RSpec.describe 'Skipping a word', type: :e2e do
  include_context 'bot e2e'

  let!(:word) { create(:word, de: 'Apfel', ru: 'apple') }

  before do
    receive(tg_user, text: '/start')
    receive(tg_user, text: MSGS[:btn_de_to_ru])
    receive(tg_user, text: MSGS[:btn_all_words])
  end

  it 'records a score of 0 for the skipped word' do
    receive(tg_user, text: MSGS[:btn_skip])
    expect(word.word_reviews.first.last_score).to eq(0)
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

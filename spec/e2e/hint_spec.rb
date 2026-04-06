require_relative 'e2e_helper'

RSpec.describe 'Hint during learning', type: :e2e do
  include_context 'bot e2e'

  # word is in its own group so the learning queue contains exactly one word.
  # Distractors have no group — hint_options pulls from all words globally.
  let!(:group)       { create(:word_group, name_ru: 'Тест', name_de: 'Test') }
  let!(:word)        { create(:word, de: 'Hund', article_de: 'der', ru: 'dog', word_group: group) }
  let!(:distractor1) { create(:word, de: 'Katze', ru: 'cat') }
  let!(:distractor2) { create(:word, de: 'Baum',  ru: 'tree') }
  let!(:distractor3) { create(:word, de: 'Apfel', ru: 'apple') }

  before do
    receive(tg_user, text: '/start')
    receive(tg_user, text: MSGS[:btn_de_to_ru])
    receive(tg_user, text: 'Тест / Test')
  end

  it 'shows 4 options including the correct answer' do
    msgs = receive(tg_user, text: MSGS[:btn_hint])
    text = msgs.last[:text]
    expect(text).to include('💡')
    expect(text.scan(/^\d\./).size).to eq(4)
    expect(text).to include('dog')
  end

  it 'shows 🎉 for a correct answer but appends the hint penalty note' do
    receive(tg_user, text: MSGS[:btn_hint])
    msgs = receive(tg_user, text: 'dog')
    expect(msgs.first[:text]).to include('🎉')
    expect(msgs.first[:text]).to include(MSGS[:hint_penalty])
  end

  it 'halves the recorded score when a hint was used' do
    receive(tg_user, text: MSGS[:btn_hint])
    receive(tg_user, text: 'dog')
    expect(word.word_reviews.reload.first.last_score).to eq(50)
  end

  it 'does not penalise when no hint was used' do
    receive(tg_user, text: 'dog')
    expect(word.word_reviews.reload.first.last_score).to eq(100)
  end
end

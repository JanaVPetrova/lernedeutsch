require_relative 'e2e_helper'

RSpec.describe 'Learning: Russian → German', type: :e2e do
  include_context 'bot e2e'

  let!(:word) { create(:word, de: 'Katze', article_de: nil, ru: 'cat') }

  before { receive(tg_user, text: '/start') }

  it 'prompts with the Russian translation and accepts the German word' do
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
    expect(msgs.first[:text]).not_to include('🎉')
  end
end

require_relative 'e2e_helper'

RSpec.describe 'Global statistics', type: :e2e do
  include_context 'bot e2e'

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

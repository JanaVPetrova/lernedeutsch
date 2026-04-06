require_relative 'e2e_helper'

RSpec.describe 'Snoozing words and the stop-list', type: :e2e do
  include_context 'bot e2e'

  let!(:word) { create(:word, de: 'Buch', article_de: 'das', ru: 'book') }

  before do
    receive(tg_user, text: '/start')
    receive(tg_user, text: MSGS[:btn_de_to_ru])
    receive(tg_user, text: MSGS[:btn_all_words])
  end

  it 'marks the word as snoozed in the database' do
    receive(tg_user, text: MSGS[:btn_snooze])
    expect(word.word_reviews.first).to be_snoozed
  end

  it 'shows the snoozed word in the stop-list' do
    receive(tg_user, text: MSGS[:btn_snooze])
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

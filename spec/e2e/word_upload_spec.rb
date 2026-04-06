require_relative 'e2e_helper'

RSpec.describe 'Word upload', type: :e2e do
  include_context 'bot e2e'

  before { receive(tg_user, text: '/start') }

  describe 'uploading a new word group' do
    it 'walks the full upload flow and persists words' do
      msgs = receive(tg_user, text: MSGS[:btn_upload])
      expect(msgs.last[:text]).to include(MSGS[:upload_ask_name_ru])

      msgs = receive(tg_user, text: 'Животные')
      expect(msgs.last[:text]).to include(MSGS[:upload_ask_name_de])

      msgs = receive(tg_user, text: 'Tiere')
      expect(msgs.last[:text]).to include('Tiere')

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

  describe 'uploading to an existing group' do
    let!(:group) { create(:word_group, name_ru: 'Цвета', name_de: 'Farben') }

    it 'offers the existing group as an option and adds words to it' do
      msgs = receive(tg_user, text: MSGS[:btn_upload])
      expect(msgs.last[:text]).to eq(MSGS[:upload_pick_group])

      receive(tg_user, text: 'Цвета / Farben')

      expect {
        receive(tg_user, text: "rot\tred\nblau\tblue")
      }.to change { group.words.count }.by(2)
    end
  end
end

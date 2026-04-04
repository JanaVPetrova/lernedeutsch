require 'spec_helper'

RSpec.describe WordGroup do
  describe 'validations' do
    it 'is valid with name_ru and name_de' do
      expect(build(:word_group)).to be_valid
    end

    it 'is invalid without name_ru' do
      expect(build(:word_group, name_ru: nil)).not_to be_valid
    end

    it 'is invalid without name_de' do
      expect(build(:word_group, name_de: nil)).not_to be_valid
    end
  end

  describe 'associations' do
    it 'nullifies word_group_id on words when deleted' do
      group = create(:word_group)
      word  = create(:word, word_group: group)
      group.destroy
      expect(word.reload.word_group).to be_nil
    end

    it 'is shared across users' do
      group  = create(:word_group)
      create(:word, word_group: group)
      create(:word, word_group: group)
      expect(group.words.count).to eq(2)
    end
  end
end

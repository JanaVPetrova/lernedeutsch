require 'spec_helper'

RSpec.describe WordGroup do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'is valid with name_ru, name_de, and user' do
      group = build(:word_group, user: user)
      expect(group).to be_valid
    end

    it 'is invalid without name_ru' do
      group = build(:word_group, user: user, name_ru: nil)
      expect(group).not_to be_valid
    end

    it 'is invalid without name_de' do
      group = build(:word_group, user: user, name_de: nil)
      expect(group).not_to be_valid
    end

    it 'is invalid without user' do
      group = build(:word_group, user: nil)
      expect(group).not_to be_valid
    end
  end

  describe 'associations' do
    it 'destroys associated words when deleted' do
      group = create(:word_group, user: user)
      create(:word, user: user, word_group: group)
      expect { group.destroy }.to change(Word, :count).by(-1)
    end
  end
end

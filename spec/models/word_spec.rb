require 'spec_helper'

RSpec.describe Word do
  describe 'validations' do
    it 'is valid with german_word and translation' do
      expect(build(:word)).to be_valid
    end

    it 'is invalid without german_word' do
      expect(build(:word, german_word: nil)).not_to be_valid
    end

    it 'is invalid without translation' do
      expect(build(:word, translation: nil)).not_to be_valid
    end

    it 'is invalid with a duplicate german_word' do
      create(:word, german_word: 'Hund')
      expect(build(:word, german_word: 'hund')).not_to be_valid
    end

    it 'is invalid with an unrecognised article' do
      expect(build(:word, article: 'le')).not_to be_valid
    end

    it 'allows a nil article' do
      expect(build(:word, article: nil)).to be_valid
    end

    %w[der die das].each do |article|
      it "allows article '#{article}'" do
        expect(build(:word, article: article)).to be_valid
      end
    end
  end

  describe '#full_german' do
    it 'returns just the word when there is no article' do
      word = build(:word, german_word: 'gehen', article: nil)
      expect(word.full_german).to eq('gehen')
    end

    it 'prepends the article when present' do
      word = build(:word, german_word: 'Hund', article: 'der')
      expect(word.full_german).to eq('der Hund')
    end
  end

  describe 'associations' do
    it 'can belong to a word_group' do
      group = create(:word_group)
      word  = create(:word, word_group: group)
      expect(word.reload.word_group).to eq(group)
    end

    it 'word_group is optional' do
      expect(create(:word, word_group: nil)).to be_persisted
    end

    it 'has many word_reviews (one per user)' do
      word  = create(:word)
      user1 = create(:user)
      user2 = create(:user)
      create(:word_review, word: word, user: user1)
      create(:word_review, word: word, user: user2)
      expect(word.word_reviews.count).to eq(2)
    end
  end
end

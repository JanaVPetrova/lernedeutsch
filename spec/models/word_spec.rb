require 'spec_helper'

RSpec.describe Word do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'is valid with german_word and translation' do
      expect(build(:word, user: user)).to be_valid
    end

    it 'is invalid without german_word' do
      expect(build(:word, user: user, german_word: nil)).not_to be_valid
    end

    it 'is invalid without translation' do
      expect(build(:word, user: user, translation: nil)).not_to be_valid
    end

    it 'is invalid with a duplicate german_word for the same user' do
      create(:word, user: user, german_word: 'Hund')
      expect(build(:word, user: user, german_word: 'hund')).not_to be_valid
    end

    it 'allows the same german_word for different users' do
      other_user = create(:user)
      create(:word, user: user, german_word: 'Hund')
      expect(build(:word, user: other_user, german_word: 'Hund')).to be_valid
    end

    it 'is invalid with an unrecognised article' do
      expect(build(:word, user: user, article: 'le')).not_to be_valid
    end

    it 'allows a nil article' do
      expect(build(:word, user: user, article: nil)).to be_valid
    end

    %w[der die das].each do |article|
      it "allows article '#{article}'" do
        expect(build(:word, user: user, article: article)).to be_valid
      end
    end
  end

  describe '#full_german' do
    it 'returns just the word when there is no article' do
      word = build(:word, user: user, german_word: 'gehen', article: nil)
      expect(word.full_german).to eq('gehen')
    end

    it 'prepends the article when present' do
      word = build(:word, user: user, german_word: 'Hund', article: 'der')
      expect(word.full_german).to eq('der Hund')
    end
  end

  describe 'after_create callback' do
    it 'auto-creates a WordReview with today as due_date' do
      word = Word.create!(user: user, german_word: 'Katze', translation: 'cat')
      review = word.word_review
      expect(review).not_to be_nil
      expect(review.due_date).to eq(Date.today)
    end
  end

  describe 'associations' do
    it 'can belong to a word_group' do
      group = create(:word_group, user: user)
      word  = create(:word, user: user, word_group: group)
      expect(word.reload.word_group).to eq(group)
    end

    it 'word_group is optional' do
      word = create(:word, user: user, word_group: nil)
      expect(word).to be_persisted
    end
  end
end

require 'spec_helper'

RSpec.describe Word do
  describe 'validations' do
    it 'is valid with de and ru' do
      expect(build(:word)).to be_valid
    end

    it 'is invalid without de' do
      expect(build(:word, de: nil)).not_to be_valid
    end

    it 'is invalid without ru' do
      expect(build(:word, ru: nil)).not_to be_valid
    end

    it 'is invalid when the same (de, ru) pair already exists' do
      create(:word, de: 'Hund', ru: 'dog')
      expect(build(:word, de: 'hund', ru: 'dog')).not_to be_valid
    end

    it 'treats punctuation and spacing variants as the same word' do
      create(:word, de: 'Die Speisekarte, bitte', ru: 'счёт, пожалуйста')
      expect(build(:word, de: 'die Speisekarte bitte.', ru: 'счёт пожалуйста')).not_to be_valid
    end

    it 'allows the same de with a different ru (synonym)' do
      create(:word, de: 'Freund', ru: 'friend')
      expect(build(:word, de: 'Freund', ru: 'pal')).to be_valid
    end

    it 'is invalid with an unrecognised article_de' do
      expect(build(:word, article_de: 'le')).not_to be_valid
    end

    it 'allows a nil article_de' do
      expect(build(:word, article_de: nil)).to be_valid
    end

    %w[der die das].each do |article|
      it "allows article_de '#{article}'" do
        expect(build(:word, article_de: article)).to be_valid
      end
    end
  end

  describe '#full_german' do
    it 'returns just de when there is no article_de' do
      word = build(:word, de: 'gehen', article_de: nil)
      expect(word.full_german).to eq('gehen')
    end

    it 'prepends article_de when present' do
      word = build(:word, de: 'Hund', article_de: 'der')
      expect(word.full_german).to eq('der Hund')
    end

    it 'does not include de_context' do
      word = build(:word, de: 'stören', article_de: nil, de_context: '(jmdn.)')
      expect(word.full_german).to eq('stören')
    end
  end

  describe '#display_translation' do
    it 'does not include ru_context' do
      word = build(:word, ru: 'мешать', ru_context: '(кому-то)')
      expect(word.display_translation).to eq('мешать')
    end
  end

  describe '#prompt_de' do
    it 'returns full_german when de_context is absent' do
      word = build(:word, de: 'Hund', article_de: 'der', de_context: nil)
      expect(word.prompt_de).to eq('der Hund')
    end

    it 'appends de_context in italics when present' do
      word = build(:word, de: 'stören', article_de: nil, de_context: '(jmdn.)')
      expect(word.prompt_de).to eq('stören _(jmdn.)_')
    end
  end

  describe '#prompt_ru' do
    it 'returns ru when ru_context is absent' do
      word = build(:word, ru: 'мешать', ru_context: nil)
      expect(word.prompt_ru).to eq('мешать')
    end

    it 'appends ru_context in italics when present' do
      word = build(:word, ru: 'мешать', ru_context: '(кому-то что-то делать)')
      expect(word.prompt_ru).to eq('мешать _(кому-то что-то делать)_')
    end
  end

  describe '#alternatives_translation' do
    it 'returns just its own ru when no synonyms exist' do
      word = create(:word, de: 'Hund', ru: 'dog')
      expect(word.alternatives_translation).to eq(['dog'])
    end

    it 'returns all ru values sharing the same de_normalized' do
      create(:word, de: 'Freund', ru: 'friend')
      create(:word, de: 'Freund', ru: 'pal')
      word = Word.find_by(ru: 'friend')
      expect(word.alternatives_translation).to contain_exactly('friend', 'pal')
    end
  end

  describe '#alternatives_de' do
    it 'returns just its own german form when no synonyms exist' do
      word = create(:word, de: 'Hund', article_de: 'der', ru: 'dog')
      expect(word.alternatives_de).to eq(['der Hund'])
    end

    it 'returns all german forms sharing the same ru_normalized' do
      create(:word, de: 'Freund',    article_de: 'der', ru: 'friend')
      create(:word, de: 'Bekannter', article_de: 'der', ru: 'friend')
      word = Word.find_by(de: 'Freund')
      expect(word.alternatives_de).to contain_exactly('der Freund', 'der Bekannter')
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

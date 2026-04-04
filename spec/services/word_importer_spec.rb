require 'spec_helper'

RSpec.describe WordImporter do
  # ── .split_article ───────────────────────────────────────────────────────────

  describe '.split_article' do
    it 'splits "der Hund" into ["der", "Hund"]' do
      expect(described_class.split_article('der Hund')).to eq(%w[der Hund])
    end

    it 'splits "die Katze" into ["die", "Katze"]' do
      expect(described_class.split_article('die Katze')).to eq(%w[die Katze])
    end

    it 'splits "das Haus" into ["das", "Haus"]' do
      expect(described_class.split_article('das Haus')).to eq(%w[das Haus])
    end

    it 'returns [nil, word] when there is no article' do
      expect(described_class.split_article('gehen')).to eq([nil, 'gehen'])
    end

    it 'is case-insensitive for article detection' do
      expect(described_class.split_article('Der Hund')).to eq(%w[der Hund])
    end

    it 'treats an unrecognised first word as part of the German word' do
      expect(described_class.split_article('mein Hund')).to eq([nil, 'mein Hund'])
    end
  end

  # ── .parse ───────────────────────────────────────────────────────────────────

  describe '.parse' do
    it 'parses simple TSV lines' do
      content = "gehen\tto go\nschlafen\tto sleep"
      result  = described_class.parse(content)
      expect(result).to eq([
        { german_word: 'gehen',    article: nil, translation: 'to go'    },
        { german_word: 'schlafen', article: nil, translation: 'to sleep' }
      ])
    end

    it 'extracts the article when present' do
      content = "der Hund\tdog"
      result  = described_class.parse(content)
      expect(result.first).to include(german_word: 'Hund', article: 'der', translation: 'dog')
    end

    it 'strips whitespace from both columns' do
      content = "  der Hund  \t  dog  "
      result  = described_class.parse(content)
      expect(result.first).to include(german_word: 'Hund', article: 'der', translation: 'dog')
    end

    it 'skips blank lines' do
      content = "gehen\tto go\n\nschlafen\tto sleep"
      expect(described_class.parse(content).length).to eq(2)
    end

    it 'skips lines starting with #' do
      content = "# comment\ngehen\tto go"
      result  = described_class.parse(content)
      expect(result.length).to eq(1)
      expect(result.first[:german_word]).to eq('gehen')
    end

    it 'skips rows with missing translation' do
      content = "gehen\t"
      expect(described_class.parse(content)).to be_empty
    end

    it 'strips UTF-8 BOM' do
      content = "\xEF\xBB\xBFgehen\tto go"
      result  = described_class.parse(content)
      expect(result.first[:german_word]).to eq('gehen')
    end

    it 'returns an empty array for empty content' do
      expect(described_class.parse('')).to be_empty
    end
  end

  # ── .import ──────────────────────────────────────────────────────────────────

  describe '.import' do
    let(:words_data) do
      [
        { german_word: 'Hund',     article: 'der', translation: 'dog'   },
        { german_word: 'Katze',    article: 'die', translation: 'cat'   },
        { german_word: 'schlafen', article: nil,   translation: 'sleep' }
      ]
    end

    it 'creates new word records' do
      expect { described_class.import(words_data) }.to change(Word, :count).by(3)
    end

    it 'returns the count of created words' do
      expect(described_class.import(words_data)).to eq(3)
    end

    it 'persists the article' do
      described_class.import(words_data)
      expect(Word.find_by(german_word: 'Hund').article).to eq('der')
    end

    it 'skips words that already exist globally' do
      described_class.import(words_data)
      expect(described_class.import(words_data)).to eq(0)
    end

    it 'assigns the word_group when provided' do
      group = create(:word_group)
      described_class.import(words_data, word_group: group)
      expect(Word.all.map(&:word_group).uniq).to eq([group])
    end

    it 'leaves word_group nil when not provided' do
      described_class.import(words_data)
      expect(Word.all.map(&:word_group).uniq).to eq([nil])
    end
  end
end

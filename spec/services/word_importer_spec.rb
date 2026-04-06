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
        { de: 'gehen',    article_de: nil, ru: 'to go'    },
        { de: 'schlafen', article_de: nil, ru: 'to sleep' }
      ])
    end

    it 'extracts article_de when present' do
      content = "der Hund\tdog"
      result  = described_class.parse(content)
      expect(result.first).to include(de: 'Hund', article_de: 'der', ru: 'dog')
    end

    it 'strips whitespace from both columns' do
      content = "  der Hund  \t  dog  "
      result  = described_class.parse(content)
      expect(result.first).to include(de: 'Hund', article_de: 'der', ru: 'dog')
    end

    it 'skips blank lines' do
      content = "gehen\tto go\n\nschlafen\tto sleep"
      expect(described_class.parse(content).length).to eq(2)
    end

    it 'skips lines starting with #' do
      content = "# comment\ngehen\tto go"
      result  = described_class.parse(content)
      expect(result.length).to eq(1)
      expect(result.first[:de]).to eq('gehen')
    end

    it 'skips rows with missing ru' do
      content = "gehen\t"
      expect(described_class.parse(content)).to be_empty
    end

    it 'strips UTF-8 BOM' do
      content = "\xEF\xBB\xBFgehen\tto go"
      result  = described_class.parse(content)
      expect(result.first[:de]).to eq('gehen')
    end

    it 'returns an empty array for empty content' do
      expect(described_class.parse('')).to be_empty
    end

    context 'with pipe-separated synonyms' do
      it 'expands multiple ru values into separate rows' do
        content = "der Hund\tdog|hound"
        result  = described_class.parse(content)
        expect(result).to contain_exactly(
          { de: 'Hund', article_de: 'der', ru: 'dog'   },
          { de: 'Hund', article_de: 'der', ru: 'hound' }
        )
      end

      it 'expands multiple German forms into separate rows' do
        content = "Freund|Bekannter\tfriend"
        result  = described_class.parse(content)
        expect(result).to contain_exactly(
          { de: 'Freund',    article_de: nil, ru: 'friend' },
          { de: 'Bekannter', article_de: nil, ru: 'friend' }
        )
      end

      it 'produces the cross-product when both sides have pipes' do
        content = "der Freund|die Freundin\tfriend|pal"
        result  = described_class.parse(content)
        expect(result.size).to eq(4)
      end

      it 'extracts article_de from each German alternative' do
        content = "der Freund|die Freundin\tfriend"
        result  = described_class.parse(content)
        expect(result).to contain_exactly(
          { de: 'Freund',   article_de: 'der', ru: 'friend' },
          { de: 'Freundin', article_de: 'die', ru: 'friend' }
        )
      end
    end
  end

  # ── .import ──────────────────────────────────────────────────────────────────

  describe '.import' do
    let(:words_data) do
      [
        { de: 'Hund',     article_de: 'der', ru: 'dog'   },
        { de: 'Katze',    article_de: 'die', ru: 'cat'   },
        { de: 'schlafen', article_de: nil,   ru: 'sleep' }
      ]
    end

    it 'creates new word records' do
      expect { described_class.import(words_data) }.to change(Word, :count).by(3)
    end

    it 'returns the count of created words' do
      expect(described_class.import(words_data)).to eq(3)
    end

    it 'persists article_de' do
      described_class.import(words_data)
      expect(Word.find_by(de: 'Hund').article_de).to eq('der')
    end

    it 'skips pairs that already exist' do
      described_class.import(words_data)
      expect(described_class.import(words_data)).to eq(0)
    end

    it 'deduplicates punctuation/spacing variants of the same word' do
      described_class.import([{ de: 'Die Speisekarte, bitte', article_de: nil, ru: 'счёт, пожалуйста' }])
      expect {
        described_class.import([{ de: 'die Speisekarte bitte.', article_de: nil, ru: 'счёт пожалуйста' }])
      }.not_to change(Word, :count)
    end

    it 'allows the same de with a different ru (synonym)' do
      described_class.import([{ de: 'Freund', article_de: 'der', ru: 'friend' }])
      expect {
        described_class.import([{ de: 'Freund', article_de: 'der', ru: 'pal' }])
      }.to change(Word, :count).by(1)
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

require 'spec_helper'

RSpec.describe AnswerScorer do
  describe '.score' do
    subject(:score) { described_class.score(expected: expected, given: given) }

    context 'when the answer is empty' do
      let(:expected) { 'dog' }
      let(:given)    { '' }

      it { is_expected.to eq(0) }
    end

    context 'when the answer is exactly correct (no article)' do
      let(:expected) { 'dog' }
      let(:given)    { 'dog' }

      it { is_expected.to eq(100) }
    end

    context 'when the answer is exactly correct (with article)' do
      let(:expected) { 'der Hund' }
      let(:given)    { 'der Hund' }

      it { is_expected.to eq(100) }
    end

    context 'when answer and expected differ only in case' do
      let(:expected) { 'dog' }
      let(:given)    { 'Dog' }

      it { is_expected.to eq(100) }
    end

    context 'when the word is correct but article is wrong' do
      let(:expected) { 'der Hund' }
      let(:given)    { 'die Hund' }

      it 'penalises the article and still gives a high score' do
        expect(score).to be_between(50, 99)
      end
    end

    context 'when the word is correct but article is missing' do
      let(:expected) { 'der Hund' }
      let(:given)    { 'Hund' }

      it 'penalises the missing article' do
        expect(score).to be_between(50, 99)
      end
    end

    context 'with a minor typo' do
      let(:expected) { 'house' }
      let(:given)    { 'hoose' }

      it 'returns a high partial score' do
        expect(score).to be_between(50, 99)
      end
    end

    context 'with a completely wrong answer' do
      let(:expected) { 'butterfly' }
      let(:given)    { 'xyz' }

      it 'returns a low score' do
        expect(score).to be < 50
      end
    end

    context 'when expected has no article and given has one' do
      let(:expected) { 'gehen' }
      let(:given)    { 'der gehen' }

      it 'returns a non-zero score' do
        expect(score).to be > 0
      end
    end

    # ── Service-mark stripping ─────────────────────────────────────────────────

    context 'when expected contains a service mark like (мн.)' do
      let(:expected) { 'собаки (мн.)' }
      let(:given)    { 'собаки' }

      it 'scores 100 — the mark is ignored' do
        expect(score).to eq(100)
      end
    end

    context 'when both expected and given contain the service mark' do
      let(:expected) { 'собаки (мн.)' }
      let(:given)    { 'собаки (мн.)' }

      it { is_expected.to eq(100) }
    end

    context 'when expected has multiple parenthetical marks' do
      let(:expected) { 'идти (куда-л.) (пешком)' }
      let(:given)    { 'идти' }

      it 'strips all marks and scores correctly' do
        expect(score).to eq(100)
      end
    end

    context 'when the service mark appears mid-word in expected' do
      let(:expected) { 'die Hand (Hände)' }
      let(:given)    { 'die Hand' }

      it 'strips the parenthetical and scores 100' do
        expect(score).to eq(100)
      end
    end
  end
end

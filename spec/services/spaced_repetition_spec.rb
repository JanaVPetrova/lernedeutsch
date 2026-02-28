require 'spec_helper'

RSpec.describe SpacedRepetition do
  let(:user)   { create(:user) }
  let(:word)   { create(:word, :with_article, user: user) }
  let(:review) { create(:word_review, word: word, user: user) }

  describe '.update' do
    subject(:update) { described_class.update(review, score) }

    context 'with a perfect score (100)' do
      let(:score) { 100 }

      it 'increments repetitions' do
        expect { update }.to change { review.repetitions }.by(1)
      end

      it 'sets due_date in the future' do
        update
        expect(review.due_date).to be > Date.today
      end

      it 'keeps ease_factor at or above minimum' do
        update
        expect(review.ease_factor).to be >= SpacedRepetition::MIN_EASE_FACTOR
      end
    end

    context 'with a passing score (75)' do
      let(:score) { 75 }

      it 'increments repetitions' do
        expect { update }.to change { review.repetitions }.by(1)
      end
    end

    context 'with a failing score (50)' do
      let(:score) { 50 }

      it 'resets repetitions to zero' do
        review.update!(repetitions: 3)
        update
        expect(review.repetitions).to eq(0)
      end

      it 'sets interval to 1' do
        review.update!(interval: 10)
        update
        expect(review.interval).to eq(1)
      end

      it 'schedules due_date for tomorrow' do
        update
        expect(review.due_date).to eq(Date.today + 1)
      end
    end

    context 'with a zero score' do
      let(:score) { 0 }

      it 'resets repetitions' do
        review.update!(repetitions: 5)
        update
        expect(review.repetitions).to eq(0)
      end
    end

    context 'interval progression' do
      it 'uses interval=1 after first success' do
        described_class.update(review, 100)
        expect(review.interval).to eq(1)
      end

      it 'uses interval=6 after second success' do
        review.update!(repetitions: 1, interval: 1)
        described_class.update(review, 100)
        expect(review.interval).to eq(6)
      end

      it 'multiplies by ease_factor after third+ success' do
        review.update!(repetitions: 2, interval: 6, ease_factor: 2.5)
        described_class.update(review, 100)
        expect(review.interval).to eq(15)  # (6 * 2.5).round
      end
    end

    context 'ease_factor floor' do
      it 'never drops below MIN_EASE_FACTOR' do
        review.update!(ease_factor: 1.3)
        described_class.update(review, 60)  # quality=3, barely passing
        expect(review.ease_factor).to be >= SpacedRepetition::MIN_EASE_FACTOR
      end
    end
  end
end

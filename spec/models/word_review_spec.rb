require 'spec_helper'

RSpec.describe WordReview do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'is valid with all required fields' do
      expect(build(:word_review, user: user, word: create(:word))).to be_valid
    end

    it 'is invalid without due_date' do
      expect(build(:word_review, user: user, due_date: nil)).not_to be_valid
    end

    it 'is invalid with ease_factor below 1.3' do
      expect(build(:word_review, user: user, ease_factor: 1.2)).not_to be_valid
    end

    it 'is invalid with negative repetitions' do
      expect(build(:word_review, user: user, repetitions: -1)).not_to be_valid
    end

    it 'is invalid with interval of zero' do
      expect(build(:word_review, user: user, interval: 0)).not_to be_valid
    end
  end

  describe '.next_for_user' do
    context 'when no words exist' do
      it 'returns nil' do
        expect(described_class.next_for_user(user)).to be_nil
      end
    end

    context 'when a word exists without a review yet' do
      let!(:word) { create(:word) }

      it 'auto-provisions a review and returns it' do
        result = described_class.next_for_user(user)
        expect(result).not_to be_nil
        expect(result.word).to eq(word)
        expect(result.user).to eq(user)
      end

      it 'does not provision a review for another user' do
        other = create(:user)
        described_class.next_for_user(user)
        expect(WordReview.for_user(other).count).to eq(0)
      end
    end

    context 'when a review exists and is due' do
      let(:word)    { create(:word) }
      let!(:review) { create(:word_review, word: word, user: user, due_date: Date.today) }

      it 'returns the due review' do
        expect(described_class.next_for_user(user)).to eq(review)
      end
    end

    context 'when a review is in the future' do
      let(:word) { create(:word) }
      let!(:review) { create(:word_review, word: word, user: user, due_date: Date.today + 1) }

      it 'returns nil' do
        expect(described_class.next_for_user(user)).to be_nil
      end
    end

    context 'returns a review from the earliest due_date batch' do
      let(:word1)  { create(:word) }
      let(:word2)  { create(:word) }
      let!(:newer) { create(:word_review, word: word1, user: user, due_date: Date.today) }
      let!(:older) { create(:word_review, word: word2, user: user, due_date: Date.today - 3) }

      it 'never returns the newer one when an older one exists' do
        results = 10.times.map { described_class.next_for_user(user) }
        expect(results).to all(eq(older))
      end
    end

    context 'with group filter' do
      let(:group)      { create(:word_group) }
      let(:word_in)    { create(:word, word_group: group) }
      let(:word_out)   { create(:word, word_group: nil) }
      let!(:review_in) { create(:word_review, word: word_in,  user: user, due_date: Date.today) }
      let!(:review_out){ create(:word_review, word: word_out, user: user, due_date: Date.today) }

      it 'returns only the review for the given group' do
        expect(described_class.next_for_user(user, group: group)).to eq(review_in)
      end
    end

    context 'with :ungrouped filter' do
      let(:group)            { create(:word_group) }
      let(:grouped_word)     { create(:word, word_group: group) }
      let(:ungrouped_word)   { create(:word, word_group: nil) }
      let!(:grouped_review)  { create(:word_review, word: grouped_word,   user: user, due_date: Date.today) }
      let!(:ungrouped_review){ create(:word_review, word: ungrouped_word, user: user, due_date: Date.today) }

      it 'returns only ungrouped words' do
        expect(described_class.next_for_user(user, group: :ungrouped)).to eq(ungrouped_review)
      end
    end

    context 'with nil group (all words)' do
      let(:group) { create(:word_group) }
      let(:word1) { create(:word, word_group: group) }
      let(:word2) { create(:word, word_group: nil) }
      let!(:r1)   { create(:word_review, word: word1, user: user, due_date: Date.today - 1) }
      let!(:r2)   { create(:word_review, word: word2, user: user, due_date: Date.today) }

      it 'returns the earliest across all groups' do
        expect(described_class.next_for_user(user, group: nil)).to eq(r1)
      end
    end

    context 'two users see the same words independently' do
      let(:other) { create(:user) }
      let!(:word) { create(:word) }

      it 'provisions separate reviews per user' do
        described_class.next_for_user(user)
        described_class.next_for_user(other)
        expect(WordReview.where(word: word).count).to eq(2)
      end
    end
  end

  describe '.due_count_for_user' do
    let(:word1) { create(:word) }
    let(:word2) { create(:word) }

    it 'counts due reviews' do
      create(:word_review, word: word1, user: user, due_date: Date.today)
      create(:word_review, word: word2, user: user, due_date: Date.today + 1)
      expect(described_class.due_count_for_user(user)).to eq(1)
    end

    it 'returns 0 when nothing is due' do
      create(:word_review, word: word1, user: user, due_date: Date.today + 5)
      expect(described_class.due_count_for_user(user)).to eq(0)
    end

    it 'respects group filter' do
      group = create(:word_group)
      w_in  = create(:word, word_group: group)
      w_out = create(:word)
      create(:word_review, word: w_in,  user: user, due_date: Date.today)
      create(:word_review, word: w_out, user: user, due_date: Date.today)
      expect(described_class.due_count_for_user(user, group: group)).to eq(1)
    end
  end
end

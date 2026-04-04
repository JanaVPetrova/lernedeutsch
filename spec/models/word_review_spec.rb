require 'spec_helper'

RSpec.describe WordReview do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'is valid with all required fields' do
      expect(build(:word_review, user: user, word: create(:word, user: user))).to be_valid
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
    context 'when no reviews are due' do
      it 'returns nil' do
        expect(described_class.next_for_user(user)).to be_nil
      end
    end

    context 'when a review is due' do
      let(:word)    { create(:word, user: user) }
      let!(:review) { create(:word_review, word: word, user: user, due_date: Date.today) }

      it 'returns the due review' do
        expect(described_class.next_for_user(user)).to eq(review)
      end
    end

    context 'when a review is in the future' do
      let(:word)    { create(:word, user: user) }
      let!(:review) { create(:word_review, word: word, user: user, due_date: Date.today + 1) }

      it 'returns nil' do
        expect(described_class.next_for_user(user)).to be_nil
      end
    end

    context 'returns the earliest due review' do
      let(:word1) { create(:word, user: user) }
      let(:word2) { create(:word, user: user) }
      let!(:newer) { create(:word_review, word: word1, user: user, due_date: Date.today) }
      let!(:older) { create(:word_review, word: word2, user: user, due_date: Date.today - 3) }

      it 'returns the oldest due review first' do
        expect(described_class.next_for_user(user)).to eq(older)
      end
    end

    context 'with group filter' do
      let(:group)         { create(:word_group, user: user) }
      let(:word_in)       { create(:word, user: user, word_group: group) }
      let(:word_out)      { create(:word, user: user, word_group: nil) }
      let!(:review_in)    { create(:word_review, word: word_in,  user: user, due_date: Date.today) }
      let!(:review_out)   { create(:word_review, word: word_out, user: user, due_date: Date.today) }

      it 'returns only the review for the given group' do
        expect(described_class.next_for_user(user, group: group)).to eq(review_in)
      end

      it 'excludes words outside the group' do
        result = described_class.next_for_user(user, group: group)
        expect(result).not_to eq(review_out)
      end
    end

    context 'with :ungrouped filter' do
      let(:group)          { create(:word_group, user: user) }
      let(:grouped_word)   { create(:word, user: user, word_group: group) }
      let(:ungrouped_word) { create(:word, user: user, word_group: nil) }
      let!(:grouped_review)   { create(:word_review, word: grouped_word,   user: user, due_date: Date.today) }
      let!(:ungrouped_review) { create(:word_review, word: ungrouped_word, user: user, due_date: Date.today) }

      it 'returns only ungrouped words' do
        expect(described_class.next_for_user(user, group: :ungrouped)).to eq(ungrouped_review)
      end
    end

    context 'with nil group (all words)' do
      let(:group) { create(:word_group, user: user) }
      let(:word1) { create(:word, user: user, word_group: group) }
      let(:word2) { create(:word, user: user, word_group: nil) }
      let!(:r1)   { create(:word_review, word: word1, user: user, due_date: Date.today - 1) }
      let!(:r2)   { create(:word_review, word: word2, user: user, due_date: Date.today) }

      it 'returns the earliest across all groups' do
        expect(described_class.next_for_user(user, group: nil)).to eq(r1)
      end
    end
  end

  describe '.due_count_for_user' do
    let(:word1) { create(:word, user: user) }
    let(:word2) { create(:word, user: user) }

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
      group = create(:word_group, user: user)
      w_in  = create(:word, user: user, word_group: group)
      w_out = create(:word, user: user)
      create(:word_review, word: w_in,  user: user, due_date: Date.today)
      create(:word_review, word: w_out, user: user, due_date: Date.today)
      expect(described_class.due_count_for_user(user, group: group)).to eq(1)
    end
  end
end

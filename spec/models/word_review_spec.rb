require 'spec_helper'

RSpec.describe WordReview do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'is valid with all required fields' do
      expect(build(:word_review, user: user, word: create(:word))).to be_valid
    end

    it 'is invalid with box below 1' do
      expect(build(:word_review, user: user, box: 0)).not_to be_valid
    end

    it 'is invalid with box above 5' do
      expect(build(:word_review, user: user, box: 6)).not_to be_valid
    end

    it 'is invalid with negative due_session' do
      expect(build(:word_review, user: user, due_session: -1)).not_to be_valid
    end
  end

  describe '.queue_for_user' do
    context 'when no words exist' do
      it 'returns an empty array' do
        expect(described_class.queue_for_user(user)).to eq([])
      end
    end

    context 'when a word exists without a review yet' do
      let!(:word) { create(:word) }

      it 'auto-provisions a review and includes it in the queue' do
        queue = described_class.queue_for_user(user)
        expect(queue).not_to be_empty
        expect(WordReview.find(queue.first).word).to eq(word)
      end

      it 'does not provision a review for another user' do
        other = create(:user)
        described_class.queue_for_user(user)
        expect(WordReview.for_user(other).count).to eq(0)
      end
    end

    context 'when a review is due (due_session <= sessions_completed)' do
      let(:word)    { create(:word) }
      let!(:review) { create(:word_review, word: word, user: user, due_session: 0) }

      it 'includes the review' do
        expect(described_class.queue_for_user(user)).to include(review.id)
      end
    end

    context 'when a review is not yet due (due_session > sessions_completed)' do
      let(:word)    { create(:word) }
      let!(:review) { create(:word_review, word: word, user: user, due_session: 5) }

      it 'excludes the review' do
        # user.sessions_completed defaults to 0
        expect(described_class.queue_for_user(user)).not_to include(review.id)
      end
    end

    context 'with group filter' do
      let(:group)      { create(:word_group) }
      let(:word_in)    { create(:word, word_group: group) }
      let(:word_out)   { create(:word, word_group: nil) }
      let!(:review_in) { create(:word_review, word: word_in,  user: user, due_session: 0) }
      let!(:review_out){ create(:word_review, word: word_out, user: user, due_session: 0) }

      it 'returns only reviews for the given group' do
        queue = described_class.queue_for_user(user, group: group)
        expect(queue).to     include(review_in.id)
        expect(queue).not_to include(review_out.id)
      end
    end

    context 'with :ungrouped filter' do
      let(:group)            { create(:word_group) }
      let(:grouped_word)     { create(:word, word_group: group) }
      let(:ungrouped_word)   { create(:word, word_group: nil) }
      let!(:grouped_review)  { create(:word_review, word: grouped_word,   user: user, due_session: 0) }
      let!(:ungrouped_review){ create(:word_review, word: ungrouped_word, user: user, due_session: 0) }

      it 'returns only ungrouped words' do
        queue = described_class.queue_for_user(user, group: :ungrouped)
        expect(queue).to     include(ungrouped_review.id)
        expect(queue).not_to include(grouped_review.id)
      end
    end

    context 'two users see the same words independently' do
      let(:other) { create(:user) }
      let!(:word) { create(:word) }

      it 'provisions separate reviews per user' do
        described_class.queue_for_user(user)
        described_class.queue_for_user(other)
        expect(WordReview.where(word: word).count).to eq(2)
      end
    end
  end

  describe '.due_count_for_user' do
    let(:word1) { create(:word) }
    let(:word2) { create(:word) }

    it 'counts due reviews' do
      create(:word_review, word: word1, user: user, due_session: 0)
      create(:word_review, word: word2, user: user, due_session: 5)
      expect(described_class.due_count_for_user(user)).to eq(1)
    end

    it 'returns 0 when nothing is due' do
      create(:word_review, word: word1, user: user, due_session: 5)
      expect(described_class.due_count_for_user(user)).to eq(0)
    end

    it 'respects group filter' do
      group = create(:word_group)
      w_in  = create(:word, word_group: group)
      w_out = create(:word)
      create(:word_review, word: w_in,  user: user, due_session: 0)
      create(:word_review, word: w_out, user: user, due_session: 0)
      expect(described_class.due_count_for_user(user, group: group)).to eq(1)
    end
  end

  describe '.stats_for_user' do
    let(:group) { create(:word_group) }

    it 'returns an entry per group' do
      w1 = create(:word, word_group: group)
      w2 = create(:word, word_group: nil)
      create(:word_review, word: w1, user: user, last_score: 100)
      create(:word_review, word: w2, user: user, last_score: 0)
      stats = described_class.stats_for_user(user)
      expect(stats.map { |g| g[:name_ru] }).to include(group.name_ru, '(без группы)')
    end

    it 'counts perfect scores' do
      w = create(:word, word_group: group)
      create(:word_review, word: w, user: user, last_score: 100)
      g = described_class.stats_for_user(user).find { |s| s[:name_ru] == group.name_ru }
      expect(g[:perfect]).to eq(1)
      expect(g[:almost]).to eq(0)
    end

    it 'counts almost scores (75–99)' do
      w = create(:word, word_group: group)
      create(:word_review, word: w, user: user, last_score: 80)
      g = described_class.stats_for_user(user).find { |s| s[:name_ru] == group.name_ru }
      expect(g[:almost]).to eq(1)
    end

    it 'counts skipped (score 0)' do
      w = create(:word, word_group: group)
      create(:word_review, word: w, user: user, last_score: 0)
      g = described_class.stats_for_user(user).find { |s| s[:name_ru] == group.name_ru }
      expect(g[:skipped]).to eq(1)
    end

    it 'counts unreviewed words (last_score nil)' do
      w = create(:word, word_group: group)
      create(:word_review, word: w, user: user, last_score: nil)
      g = described_class.stats_for_user(user).find { |s| s[:name_ru] == group.name_ru }
      expect(g[:unreviewed]).to eq(1)
    end

    it 'only shows stats for the given user' do
      other = create(:user)
      w = create(:word, word_group: group)
      create(:word_review, word: w, user: other, last_score: 100)
      g = described_class.stats_for_user(user).find { |s| s[:name_ru] == group.name_ru }
      expect(g[:unreviewed]).to eq(1)
      expect(g[:perfect]).to eq(0)
    end
  end
end

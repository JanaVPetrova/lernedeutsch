require 'spec_helper'

RSpec.describe SpacedRepetition do
  let(:user)   { create(:user) }
  let(:word)   { create(:word, :with_article) }
  let(:review) { create(:word_review, word: word, user: user, box: 1, due_session: 0) }

  describe '.update' do
    subject(:update) { described_class.update(review, score, current_session) }

    let(:current_session) { 3 }

    # ── Perfect score ──────────────────────────────────────────────────────────

    context 'with a perfect score (100)' do
      let(:score) { 100 }

      it 'advances the box by 1' do
        expect { update }.to change { review.box }.from(1).to(2)
      end

      it 'schedules due_session = current + box_interval(new_box)' do
        update
        # new box=2, interval=2 → due_session = 3+2 = 5
        expect(review.due_session).to eq(5)
      end

      it 'saves last_score' do
        update
        expect(review.last_score).to eq(100)
      end
    end

    # ── Almost score ───────────────────────────────────────────────────────────

    context 'with an almost score (75)' do
      let(:score) { 75 }

      it 'advances the box by 1' do
        expect { update }.to change { review.box }.from(1).to(2)
      end

      it 'schedules due_session correctly' do
        update
        expect(review.due_session).to eq(5) # current 3 + interval 2
      end
    end

    # ── Partial score ──────────────────────────────────────────────────────────

    context 'with a partial score (50)' do
      let(:score) { 50 }

      it 'keeps the box unchanged' do
        expect { update }.not_to change { review.box }
      end

      it 'schedules due_session = current + box_interval(box)' do
        update
        expect(review.due_session).to eq(4) # current 3 + interval 1
      end
    end

    # ── Wrong score ────────────────────────────────────────────────────────────

    context 'with a wrong score (30)' do
      let(:score) { 30 }

      it 'drops the box by 1 (min 1)' do
        review.update!(box: 3)
        update
        expect(review.box).to eq(2)
      end

      it 'does not drop box below 1' do
        review.update!(box: 1)
        update
        expect(review.box).to eq(1)
      end

      it 'schedules due next session' do
        update
        expect(review.due_session).to eq(4) # current 3 + interval 1 (box stays 1)
      end
    end

    # ── Zero / skip ────────────────────────────────────────────────────────────

    context 'with score 0 (skip)' do
      let(:score) { 0 }

      it 'drops the box (min 1)' do
        review.update!(box: 2)
        update
        expect(review.box).to eq(1)
      end
    end

    # ── Box ceiling ────────────────────────────────────────────────────────────

    context 'when already at box 5' do
      let(:score) { 100 }

      it 'does not exceed box 5' do
        review.update!(box: 5)
        update
        expect(review.box).to eq(5)
      end

      it 'schedules due_session = current + 16' do
        review.update!(box: 5)
        update
        expect(review.due_session).to eq(current_session + 16)
      end
    end

    # ── Box intervals ──────────────────────────────────────────────────────────

    context 'box interval progression' do
      let(:score) { 100 }

      { 1 => 2, 2 => 4, 3 => 8, 4 => 16 }.each do |starting_box, expected_interval|
        it "box #{starting_box} → interval #{expected_interval} after perfect answer" do
          review.update!(box: starting_box)
          update
          expect(review.due_session).to eq(current_session + expected_interval)
        end
      end
    end
  end
end

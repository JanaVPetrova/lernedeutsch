# Implements the Leitner Queue spaced repetition algorithm.
#
# Words are organised into 5 boxes. A word's box determines how many sessions
# must pass before it reappears in a new session.
#
#   Box 1: every 1 session   (new / forgotten words)
#   Box 2: every 2 sessions
#   Box 3: every 4 sessions
#   Box 4: every 8 sessions
#   Box 5: every 16 sessions (near-mastered)
#
# Within a single session, wrong/partial answers cause the word to be
# re-inserted into the session queue (handled by LearningHandler). This method
# only updates the persistent box level and due_session for the next session.
#
# Score → box change:
#   0–49  (wrong / skip) : box = max(1, box-1), due next session
#   50–74 (partial)      : box unchanged,        due in box_interval sessions
#   75–99 (almost)       : box = min(5, box+1),  due in new box_interval sessions
#   100   (perfect)      : box = min(5, box+1),  due in new box_interval sessions
class SpacedRepetition
  BOX_INTERVALS = { 1 => 1, 2 => 2, 3 => 4, 4 => 8, 5 => 16 }.freeze

  def self.update(review, score, current_session)
    new(review).update(score, current_session)
  end

  def initialize(review)
    @review = review
  end

  def update(score, current_session)
    if score < 50
      @review.box = [@review.box - 1, 1].max
    elsif score < 75
      # box unchanged
    else
      @review.box = [@review.box + 1, 5].min
    end

    @review.due_session = current_session + BOX_INTERVALS[@review.box]
    @review.last_score  = score
    @review.save!
    @review
  end
end

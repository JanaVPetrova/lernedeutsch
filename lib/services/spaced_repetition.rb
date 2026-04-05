# Implements the SM-2 spaced repetition algorithm.
#
# Quality scale (0–5) is derived from the 0–100 score:
#   0–19  => 0  (blackout)
#   20–39 => 1  (incorrect, familiar)
#   40–59 => 2  (incorrect, easy to recall)
#   60–74 => 3  (correct with difficulty)
#   75–89 => 4  (correct with hesitation)
#   90–100 => 5 (perfect)
#
# Intervals (in hours):
#   repetitions=0 => 6 hours
#   repetitions=1 => 24 hours
#   repetitions>1 => interval * ease_factor
class SpacedRepetition
  MIN_EASE_FACTOR = 1.3

  def self.update(review, score)
    new(review).update(score)
  end

  def initialize(review)
    @review = review
  end

  def update(score)
    quality = score_to_quality(score)

    if quality < 3
      @review.repetitions = 0
      @review.interval    = 1
      @review.due_date    = Time.now
    else
      @review.interval = next_interval
      @review.repetitions += 1
      @review.ease_factor = [
        (@review.ease_factor + 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)).round(2),
        MIN_EASE_FACTOR
      ].max
      @review.due_date = Time.now + @review.interval * 3600
    end

    @review.last_score = score
    @review.save!
    @review
  end

  private

  def score_to_quality(score)
    case score
    when 0..19  then 0
    when 20..39 then 1
    when 40..59 then 2
    when 60..74 then 3
    when 75..89 then 4
    else             5
    end
  end

  def next_interval
    case @review.repetitions
    when 0 then 6
    when 1 then 24
    else        (@review.interval * @review.ease_factor).round
    end
  end
end

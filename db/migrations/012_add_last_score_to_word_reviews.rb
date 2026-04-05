class AddLastScoreToWordReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :word_reviews, :last_score, :integer
  end
end

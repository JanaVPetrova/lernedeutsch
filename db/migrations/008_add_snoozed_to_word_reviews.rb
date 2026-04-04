class AddSnoozedToWordReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :word_reviews, :snoozed, :boolean, default: false, null: false
  end
end

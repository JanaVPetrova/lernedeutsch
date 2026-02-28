class CreateWordReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :word_reviews do |t|
      t.references :word, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :repetitions, default: 0,   null: false
      t.float   :ease_factor, default: 2.5, null: false
      t.integer :interval,    default: 1,   null: false  # days until next review
      t.date    :due_date,    null: false
      t.timestamps
    end

    add_index :word_reviews, %i[user_id word_id], unique: true
    add_index :word_reviews, %i[user_id due_date]
  end
end

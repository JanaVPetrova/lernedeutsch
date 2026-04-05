class AddLeitnerToReviews < ActiveRecord::Migration[8.1]
  def up
    add_column :word_reviews, :box,         :integer, null: false, default: 1
    add_column :word_reviews, :due_session, :integer, null: false, default: 0
    add_column :users,        :sessions_completed, :integer, null: false, default: 0

    # Migrate existing data: words that were due (due_date <= now) get due_session=0
    # (immediately due), everything else gets due_session=1.
    execute <<~SQL
      UPDATE word_reviews SET due_session = 0 WHERE due_date <= NOW();
      UPDATE word_reviews SET due_session = 1 WHERE due_date > NOW();
    SQL

    remove_column :word_reviews, :interval
    remove_column :word_reviews, :ease_factor
    remove_column :word_reviews, :due_date
    remove_column :word_reviews, :repetitions
  end

  def down
    add_column :word_reviews, :repetitions, :integer, null: false, default: 0
    add_column :word_reviews, :due_date,    :timestamp, null: false, default: -> { 'NOW()' }
    add_column :word_reviews, :ease_factor, :decimal, precision: 4, scale: 2, null: false, default: 2.5
    add_column :word_reviews, :interval,    :integer, null: false, default: 1

    remove_column :word_reviews, :box
    remove_column :word_reviews, :due_session
    remove_column :users,        :sessions_completed
  end
end

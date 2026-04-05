class ChangeDueDateToDatetime < ActiveRecord::Migration[8.1]
  def up
    execute "ALTER TABLE word_reviews ALTER COLUMN due_date TYPE timestamp USING due_date::timestamp"
  end

  def down
    execute "ALTER TABLE word_reviews ALTER COLUMN due_date TYPE date USING due_date::date"
  end
end

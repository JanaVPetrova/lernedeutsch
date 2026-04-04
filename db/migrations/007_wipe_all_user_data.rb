class WipeAllUserData < ActiveRecord::Migration[8.1]
  def up
    execute 'DELETE FROM word_reviews'
    execute 'DELETE FROM words'
    execute 'DELETE FROM word_groups'
    execute 'DELETE FROM reminders'
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

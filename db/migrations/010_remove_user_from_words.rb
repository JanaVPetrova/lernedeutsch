class RemoveUserFromWords < ActiveRecord::Migration[8.1]
  def change
    remove_reference :words, :user, foreign_key: true, null: false
    remove_index :words, %i[user_id german_word], if_exists: true
    add_index :words, :german_word, unique: true
  end
end

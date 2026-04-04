class RemoveUserFromWordGroups < ActiveRecord::Migration[8.1]
  def change
    remove_reference :word_groups, :user, foreign_key: true, null: false
  end
end

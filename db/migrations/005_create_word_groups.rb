class CreateWordGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :word_groups do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name_ru, null: false
      t.string :name_de, null: false
      t.timestamps
    end
  end
end

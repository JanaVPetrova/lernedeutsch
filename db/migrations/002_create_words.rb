class CreateWords < ActiveRecord::Migration[8.1]
  def change
    create_table :words do |t|
      t.references :user, null: false, foreign_key: true
      t.string :german_word, null: false
      t.string :article  # der, die, das — nil for non-nouns
      t.string :translation, null: false
      t.timestamps
    end

    add_index :words, %i[user_id german_word], unique: true
  end
end

class AddWordGroupToWords < ActiveRecord::Migration[8.1]
  def change
    add_reference :words, :word_group, foreign_key: true, null: true
  end
end

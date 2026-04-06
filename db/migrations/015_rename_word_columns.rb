class RenameWordColumns < ActiveRecord::Migration[8.1]
  def up
    rename_column :words, :german_word,             :de
    rename_column :words, :translation,             :ru
    rename_column :words, :article,                 :article_de
  end

  def down
    rename_column :words, :de,             :german_word
    rename_column :words, :ru,             :translation
    rename_column :words, :article_de,     :article
  end
end

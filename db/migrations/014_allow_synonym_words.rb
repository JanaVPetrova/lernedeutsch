class AllowSynonymWords < ActiveRecord::Migration[8.1]
  def up
    # Add normalised columns (nullable first so existing rows don't violate NOT NULL).
    add_column :words, :de_normalized, :string
    add_column :words, :ru_normalized, :string

    # Populate from existing rows: downcase + strip spaces and punctuation.
    execute <<~SQL
      UPDATE words
      SET de_normalized = LOWER(REGEXP_REPLACE(german_word, '[[:space:][:punct:]]', '', 'g')),
          ru_normalized = LOWER(REGEXP_REPLACE(translation, '[[:space:][:punct:]]', '', 'g'))
    SQL

    change_column_null :words, :de_normalized, false
    change_column_null :words, :ru_normalized, false

    # Replace the old unique index on german_word alone with one on the two
    # normalised columns — synonyms are allowed, but "Die Speisekarte, bitte"
    # and "die Speisekarte bitte." will collide as intended.
    remove_index :words, :german_word, if_exists: true
    add_index :words, %i[de_normalized ru_normalized], unique: true,
              name: 'index_words_on_de_normalized_and_ru_normalized'
  end

  def down
    remove_index :words, name: 'index_words_on_de_normalized_and_ru_normalized', if_exists: true
    add_index :words, :german_word, unique: true
    remove_column :words, :de_normalized
    remove_column :words, :ru_normalized
  end
end

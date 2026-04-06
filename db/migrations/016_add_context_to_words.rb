class AddContextToWords < ActiveRecord::Migration[8.1]
  def up
    add_column :words, :ru_context, :string, default: nil
    add_column :words, :de_context, :string, default: nil

    # Extract bracketed content from ru/de into the context columns,
    # then strip it from the main field and re-normalize.
    execute <<~SQL
      UPDATE words
      SET ru_context = SUBSTRING(ru FROM '\\(.*$'),
          ru         = TRIM(REGEXP_REPLACE(ru, '\\s*\\(.*$', ''))
      WHERE ru ~ '\\('
    SQL

    execute <<~SQL
      UPDATE words
      SET de_context = SUBSTRING(de FROM '\\(.*$'),
          de         = TRIM(REGEXP_REPLACE(de, '\\s*\\(.*$', ''))
      WHERE de ~ '\\('
    SQL

    # Re-normalize since ru/de may have changed.
    execute <<~SQL
      UPDATE words
      SET ru_normalized = LOWER(REGEXP_REPLACE(ru, '[[:space:][:punct:]]', '', 'g')),
          de_normalized = LOWER(REGEXP_REPLACE(de, '[[:space:][:punct:]]', '', 'g'))
    SQL
  end

  def down
    execute <<~SQL
      UPDATE words
      SET ru = ru || ' ' || ru_context
      WHERE ru_context IS NOT NULL AND ru_context <> ''
    SQL

    execute <<~SQL
      UPDATE words
      SET de = de || ' ' || de_context
      WHERE de_context IS NOT NULL AND de_context <> ''
    SQL

    remove_column :words, :ru_context
    remove_column :words, :de_context
  end
end

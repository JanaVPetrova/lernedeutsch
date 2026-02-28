class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.bigint :telegram_id, null: false
      t.string :first_name
      t.string :last_name
      t.string :username
      t.string :preferred_language, default: 'en', null: false
      t.timestamps
    end

    add_index :users, :telegram_id, unique: true
  end
end

class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :time, null: false                              # "HH:MM"
      t.text   :days, array: true, default: %w[mon tue wed thu fri sat sun]
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end
  end
end

class CreateHoliday < ActiveRecord::Migration
  def up
    create_table :holidays, id: :uuid do |t|
      t.string :name, null: false
      t.date :date, null: false
      t.timestamps null: false
    end
  end

  def down
    drop_table :holidays
  end
end

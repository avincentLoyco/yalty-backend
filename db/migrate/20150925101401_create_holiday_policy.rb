class CreateHolidayPolicy < ActiveRecord::Migration
  def up
    create_table :holiday_policies, id: :uuid do |t|
      t.string :name, null: false
      t.string :country
      t.string :region
      t.timestamps null: false
    end
  end

  def down
    drop_table :holiday_policies
  end
end

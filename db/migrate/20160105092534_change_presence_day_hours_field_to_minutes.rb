class ChangePresenceDayHoursFieldToMinutes < ActiveRecord::Migration
  def up
    add_column :presence_days, :minutes, :integer

    execute <<-SQL
      UPDATE presence_days
      SET minutes = (presence_days.hours * 60)
      WHERE presence_days.hours IS NOT NULL
    SQL

    remove_column :presence_days, :hours
  end

  def down
    add_column :presence_days, :hours, :decimal

    execute <<-SQL
      UPDATE presence_days
      SET hours = (presence_days.minutes/60)
      WHERE presence_days.minutes IS NOT NULL
    SQL

    remove_column :presence_days, :minutes
  end
end

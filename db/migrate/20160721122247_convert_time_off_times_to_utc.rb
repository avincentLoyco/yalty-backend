class ConvertTimeOffTimesToUtc < ActiveRecord::Migration
  def up
    TimeOff.all.each do |time_off|
      old_timezone = time_off.employee.account.timezone
      next if old_timezone == 'UTC'
      new_start_time = time_off.start_time.in_time_zone(old_timezone).to_s.split('+').first + '+00:00'
      new_end_time = time_off.end_time.in_time_zone(old_timezone).to_s.split('+').first + '+00:00'

      time_off.update_attributes(start_time: new_start_time, end_time: new_end_time)
    end
    execute "SET TIME ZONE 'UTC'"
  end
end

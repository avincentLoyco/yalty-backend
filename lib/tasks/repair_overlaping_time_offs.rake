task repair_overlaping_time_offs: [:environment] do
  invalid_time_offs = TimeOff.all.reject(&:valid?)

  working_hours_overlap = invalid_time_offs - time_offs_overlap(invalid_time_offs)

  registered_working_times_overlap(time_offs_overlap(invalid_time_offs))
  working_times_overlap(working_hours_overlap)
end

def time_offs_overlap(invalid_time_offs)
  invalid_time_offs.reject do |time_off|
    time_off.send(:does_not_overlap_with_other_users_time_offs).nil?
  end
end

def registered_working_times_overlap(overlaping_time_offs)
  leading_time_offs(overlaping_time_offs).each do |invalid_time_off|
    time_offs_to_delete(invalid_time_off).each do |time_off|
      time_off.employee_balance.destroy!
      time_off.destroy!
    end
    PrepareEmployeeBalancesToUpdate.new(balance_to_update(invalid_time_off), update_all: true)
    UpdateBalanceJob.perform_later(balance_to_update(invalid_time_off).id, update_all: true)
  end
end

def balance_to_update(invalid_time_off)
  invalid_time_off
    .employee
    .employee_balances
    .where(
      'time_off_category_id = ? AND effective_at >= ?',
      invalid_time_off.time_off_category_id, invalid_time_off.start_time
    ).order(:effective_at).first
end

def leading_time_offs(overlaping_time_offs)
  overlaping_time_offs.select do |time_off|
    time_off
      .employee
      .time_offs
      .where(
        'id != ? AND ((start_time >= ? AND start_time < ?) OR (end_time > ? AND end_time <= ?))',
        time_off.id, time_off.start_time, time_off.end_time, time_off.start_time, time_off.end_time
      ).present?
  end
end

def time_offs_to_delete(invalid_time_off)
  invalid_time_off
    .employee
    .time_offs
    .where(
      'start_time >= ? AND end_time < ? AND time_off_category_id = ?',
      invalid_time_off.start_time, invalid_time_off.end_time, invalid_time_off.time_off_category
    ).order(:start_time)
end

def working_times_overlap(working_hours_overlap)
  working_hours_overlap.each do |invalid_time_off|
    registered_working_times(invalid_time_off).each do |registered_working_time|
      if registered_working_time.date.eql?(invalid_time_off.start_time.to_date)
        start_time = TimeEntry.hour_as_time(invalid_time_off.start_time.strftime('%H:%M:%S'))
        end_time = TimeEntry.hour_as_time('24:00:00')
      elsif registered_working_time.date.eql?(invalid_time_off.end_time.to_date)
        start_time = TimeEntry.hour_as_time('00:00:00')
        end_time = TimeEntry.hour_as_time(invalid_time_off.end_time.strftime('%H:%M:%S'))
      end
      overlaps_with_registered_working_time?(registered_working_time, start_time, end_time)
    end
  end
end

def registered_working_times(invalid_time_off)
  invalid_time_off
    .employee
    .registered_working_times
    .in_day_range(invalid_time_off.start_time.to_date, invalid_time_off.end_time.to_date)
end

def overlaps_with_registered_working_time?(registered_working_time, start_time, end_time)
  entries_to_be_deleted =
    registered_working_time.time_entries.select do |time_entry|
      time_entry_start = TimeEntry.hour_as_time(time_entry['start_time'])
      time_entry_end = TimeEntry.hour_as_time(time_entry['end_time'])
      time_entry_start > start_time && time_entry_end < end_time
    end
  new_time_entries = registered_working_time.time_entries - entries_to_be_deleted
  if new_time_entries.empty?
    registered_working_time.delete
  else
    registered_working_time.update(time_entries: new_time_entries)
  end
end

namespace :regenerate do
  desc 'Regenerate registered working time'
  task registered_working_times: [:environment] do
    total = 0
    deleted = 0
    start_at = RegisteredWorkingTime.minimum(:date)
    today = Time.zone.today - 1

    (start_at..today).each do |day|
      employee_ids =
        RegisteredWorkingTime
        .where(date: day, schedule_generated: true)
        .pluck(:employee_id)

      total_day = RegisteredWorkingTime.where(date: day).count
      total +=  total_day

      deleted_day = RegisteredWorkingTime.where(date: day, employee_id: employee_ids).delete_all
      deleted += deleted_day

      puts "Regenerate #{deleted_day} of #{total_day} registered working times at #{day}"
      CreateRegisteredWorkingTime.new(day, employee_ids).call
    end

    puts "Finish to regenerate #{deleted} of #{total} registered working times"
  end

  desc 'Recalculate all time-off balances'
  task time_offs: [:environment] do
    Employee.all.each do |employee|
      time_off_categories =
        TimeOff.where(employee_id: employee.id).pluck(:time_off_category_id).uniq

      time_off_categories.each do |category_id|
        oldest_balance =
          TimeOff.where(employee_id: employee.id, time_off_category_id: category_id)
                 .order(:start_time)
                 .first
                 .employee_balance

        next if oldest_balance.time_off_policy.nil?

        PrepareEmployeeBalancesToUpdate.new(oldest_balance, update_all: true).call
        UpdateBalanceJob.perform_later(oldest_balance.id, update_all: true)
      end
    end
  end
end

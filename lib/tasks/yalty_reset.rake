namespace :yalty do
  namespace :reset do
    desc 'Reset generated registered working time'
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
  end
end

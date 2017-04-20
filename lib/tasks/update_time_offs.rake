namespace :update_time_offs do
  task for_contract_end: :environment do
    employees_with_contract_end =
      Employee::Event.where(event_type: 'contract_end').pluck(:employee_id).uniq

    TimeOff.where(employee_id: employees_with_contract_end).map do |time_off|
      next if time_off.valid? || period_with_time_off_dates?(time_off)
      time_off_period =
        time_off.employee.contract_periods.select do |period|
          period.include?(time_off.start_time)
        end
      end_time = (time_off_period.last.last + 1.day).beginning_of_day
      time_off.update!(end_time: end_time)
      time_off.employee_balance.update!(effective_at: end_time)
      PrepareEmployeeBalancesToUpdate.new(time_off.employee_balance).call
      UpdateBalanceJob.perform_later(time_off.employee_balance)
    end
  end

  def period_with_time_off_dates?(time_off)
    time_off.employee.contract_periods.any? do |period|
      (period.include?(time_off.end_time.to_date) ||
        time_off.end_time == (period.end + 1.day).beginning_of_day) &&
        period.include?(time_off.start_time.to_date)
    end
  end
end

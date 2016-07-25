namespace :recalculate do
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

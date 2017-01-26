desc 'create missing balances, verifies if time off\'s validity date is valid, if not updates its'

task update_validity_dates_for_time_offs: [:environment] do
  Employee.all.map do |employee|
    employee.employee_balances.not_removals.select do |balance|
      balance.effective_at.strftime('%H:%M:%S') == '00:00:03'
    end.map(&:destroy!)
  end

  Employee.all.map do |employee|
    employee.time_offs.order(:start_time).map do |time_off|
      employee_balance = time_off.employee_balance
      next unless employee_balance
      time_off_etop = time_off.employee_balance.employee_time_off_policy
      valid_validity_date =
        RelatedPolicyPeriod.new(time_off_etop).validity_date_for(employee_balance.effective_at)

      next unless employee_balance.validity_date != valid_validity_date ||
          (employee_balance.validity_date.present? &&
          employee_balance.balance_credit_removal_id.nil?)

      params = { update_all: true }
      if employee_balance.validity_date != valid_validity_date
        params[:validity_date] = valid_validity_date.to_s
      else
        ManageEmployeeBalanceRemoval.new(nil, employee_balance, valid_validity_date).call
      end

      PrepareEmployeeBalancesToUpdate.new(employee_balance, params).call
      UpdateBalanceJob.perform_later(employee_balance.id, params)
    end
  end

  Rake::Task[:create_balances_for_time_offs].invoke
end

namespace :employee_balance do
  task update_offsets: :environment do
    puts "update assignations and additions"
    update_additions_and_assignations
    puts "end of period balance"
    update_end_off_period_balances
    puts "update removal and reset"
    update_removals_and_validity_dates
    puts "create missing additions and removals"
    create_missing_additions_and_removals
    puts "recalculate"
    Rake::Task["db:cleanup:recalculate_all_balances"].invoke
  end

  def update_additions_and_assignations
    %w(addition assignation).map do |balance_type|
      offset = Employee::Balance.const_get("#{balance_type.upcase}_OFFSET")
      Employee::Balance.where(balance_type: balance_type).map do |balance|
        balance.update!(effective_at: balance.effective_at.to_date + offset)
      end
    end
  end

  def update_end_off_period_balances
    Employee::Balance.where(balance_type: "end_of_period").map do |balance|
      balance_policy = balance.time_off_policy

      next if balance_policy.start_day.eql?(balance.effective_at.day) &&
          balance_policy.start_month.eql?(balance.effective_at.month)

      new_effective_at = balance.effective_at + 1.day
      validity_date =
        RelatedPolicyPeriod
        .new(balance.employee_time_off_policy).validity_date_for_balance_at(new_effective_at)

      if balance.employee.contract_periods.any? { |p| p.include?(new_effective_at.to_date) }
        balance.update!(effective_at: new_effective_at, validity_date: validity_date)
      else
        balance.destroy!
      end
    end
  end

  def update_removals_and_validity_dates
    Employee::Balance.where.not(validity_date: nil).order(:effective_at).map do |balance|
      etop = balance.employee_time_off_policy
      validity_date =
        RelatedPolicyPeriod
        .new(etop)
        .validity_date_for_balance_at(balance.effective_at, balance.balance_type)
      UpdateEmployeeBalance.new(balance, validity_date: validity_date).call
    end
  end

  def create_missing_additions_and_removals
    EmployeeTimeOffPolicy.order(:effective_at).not_reset.map do |policy|
      ManageEmployeeBalanceAdditions.new(policy, false).call
    end
  end
end

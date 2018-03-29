class UpdateNextEmployeeBalances
  pattr_initialize :employee_balance

  def call
    return unless other_balances_in_period?
    PrepareEmployeeBalancesToUpdate.call(employee_balance)
    UpdateBalanceJob.perform_later(employee_balance.id)
  end

  private

  def other_balances_in_period?
    Employee::Balance
      .where("effective_at >= ?", start_time)
      .where.not(id: employee_balance.id)
      .where(employee_id: employee_balance.employee_id)
      .where(time_off_category_id: employee_balance.time_off_category_id)
      .exists?
  end

  def start_time
    [employee_balance.effective_at, employee_balance.time_off.try(:start_time)].compact.min
  end
end

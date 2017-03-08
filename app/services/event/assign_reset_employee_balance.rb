class AssignResetEmployeeBalance
  def initialize(employee_time_off_policy)
    @employee_time_off_policy = employee_time_off_policy
    @employee = employee_time_off_policy.employee
    @time_off_category = employee_time_off_policy.time_off_category
  end

  def call
    return unless @employee_time_off_policy.time_off_policy.reset?
    create_reset_employee_balance
    find_balances_with_validity_date_after_contract_end
    return unless @balances_to_update.present?
    update_balances_validity_dates
  end

  private

  def create_reset_employee_balance
    @reset_employee_balance =
      CreateEmployeeBalance.new(
        @time_off_category.id,
        @employee.id,
        @employee.account.id,
        reset_balance: true,
        effective_at: @employee_time_off_policy.effective_at + Employee::Balance::REMOVAL_OFFSET
      ).call.first
  end

  def find_balances_with_validity_date_after_contract_end
    @balances_to_update =
      @employee
      .employee_balances
      .where(time_off_category: @time_off_category)
      .where(
        'effective_at <= ? AND validity_date > ?',
        @employee_time_off_policy.effective_at, @employee_time_off_policy.effective_at
      )
      .order(:effective_at)
  end

  def update_balances_validity_dates
    @balances_to_update.map do |balance|
      UpdateEmployeeBalance.new(balance, validity_date: @reset_employee_balance.effective_at).call
    end
  end
end

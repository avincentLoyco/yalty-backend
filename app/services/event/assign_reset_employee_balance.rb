class AssignResetEmployeeBalance
  def initialize(employee_time_off_policy, old_contract_end = nil)
    @employee_time_off_policy = employee_time_off_policy
    @employee = employee_time_off_policy.employee
    @time_off_category = employee_time_off_policy.time_off_category
    @old_contract_end = find_contract_end(old_contract_end)
  end

  def call
    return unless @employee_time_off_policy.time_off_policy.reset?
    create_reset_employee_balance
    update_balances_valid_after_contract_end
    return unless @old_contract_end.present? &&
        @employee_time_off_policy.effective_at > @old_contract_end
    update_previous_balances_validity_dates
  end

  private

  def create_reset_employee_balance
    @reset_employee_balance =
      CreateEmployeeBalance.new(
        @time_off_category.id,
        @employee.id,
        @employee.account.id,
        balance_type: 'reset',
        effective_at: @employee_time_off_policy.effective_at + Employee::Balance::RESET_OFFSET
      ).call.first
  end

  def update_balances_valid_after_contract_end
    balances_valid_after_contract_end =
      @employee
      .employee_balances
      .in_category(@time_off_category.id)
      .where(
        'effective_at <= ? AND validity_date > ?',
        @employee_time_off_policy.effective_at, @employee_time_off_policy.effective_at
      ).order(:effective_at)

    balances_valid_after_contract_end.map do |balance|
      UpdateEmployeeBalance.new(balance, validity_date: @reset_employee_balance.effective_at).call
    end
  end

  def update_previous_balances_validity_dates
    old_contract_end_balances =
      @employee.employee_balances.where(validity_date: @old_contract_end).order(:effective_at)

    old_contract_end_balances.map do |balance|
      validity_date =
        RelatedPolicyPeriod
        .new(balance.employee_time_off_policy)
        .validity_date_for_balance_at(balance.effective_at, balance.balance_type)

      UpdateEmployeeBalance.new(balance, validity_date: validity_date).call
    end
  end

  def find_contract_end(old_contract_end)
    return unless old_contract_end.present?
    old_contract_end.beginning_of_day + Employee::Balance::RESET_OFFSET
  end
end

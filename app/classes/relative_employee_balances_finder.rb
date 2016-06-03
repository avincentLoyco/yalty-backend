class RelativeEmployeeBalancesFinder
  attr_reader :employee_balance, :related_balances

  def initialize(employee_balance)
    @employee_balance = employee_balance
    @related_balances = balances_related_by_category_and_employee
  end

  def previous_balances
    related_balances.where('effective_at < ?', employee_balance.now_or_effective_at)
                    .order(effective_at: :asc)
  end

  def next_balance
    related_balances.where('effective_at > ?', employee_balance.now_or_effective_at)
                    .order(effective_at: :asc).first.try(:id)
  end

  def active_balances
    related_balances
      .where(
        'effective_at < ? AND validity_date > ?',
        employee_balance.effective_at, employee_balance.effective_at
      )
  end

  def balances_related_by_category_and_employee
    Employee::Balance.employee_balances(
      employee_balance.employee_id, employee_balance.time_off_category_id
    )
  end
end

class CalculateEmployeeBalanceRemovalAmount
  attr_reader :employee_balance, :addition

  def initialize(employee_balance, addition)
    @employee_balance = employee_balance
    @addition = addition
  end

  def call
    return calculate_counter_amount if balance_belongs_to_counter_policy?
    calculate_balancer_amount
  end

  private

  def balance_belongs_to_counter_policy?
    join_model_time_off_policy =
      employee_balance
      .employee
      .active_policy_in_category_at_date(
        employee_balance.time_off_category_id, employee_balance.effective_at
      )
    return false unless join_model_time_off_policy
    join_model_time_off_policy.time_off_policy.counter?
  end

  def calculate_counter_amount
    last_balance = employee_balance.previous_balances.last.try(:balance)
    0 - last_balance.to_i
  end

  def calculate_balancer_amount
    if employee_balance.last_balance_after(addition).blank?
      amount_from_addition
    else
      amount_from_previous_balances
    end
  end

  def amount_from_addition
    return -addition.balance if addition.amount > addition.balance && addition.balance >= 0
    -addition.amount
  end

  def amount_from_previous_balances
    return 0 unless sum > 0 && sum < addition.amount
    - (addition.amount - sum)
  end

  def sum
    addition.amount - (previous_balance - positive_amounts - amount_difference)
  end

  def previous_balance
    employee_balance.previous_balances.last.try(:balance).to_i
  end

  def positive_amounts
    employee_balance.positive_balances_after(addition) +
      + employee_balance.active_balances.pluck(:amount).sum
  end

  def amount_difference
    return 0 unless addition.amount < addition.balance
    addition.balance - addition.amount
  end
end

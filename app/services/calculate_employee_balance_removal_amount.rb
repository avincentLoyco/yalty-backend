class CalculateEmployeeBalanceRemovalAmount
  attr_reader :employee_balance, :addition

  def initialize(employee_balance, addition)
    @employee_balance = employee_balance
    @addition = addition
  end

  def call
    return calculate_counter_amount if employee_balance.time_off_policy.counter?
    calculate_balancer_amount
  end

  private

  def calculate_counter_amount
    last_balance = employee_balance.previous_balances.last.try(:balance)
    0 - last_balance.to_i
  end

  def calculate_balancer_amount
    if employee_balance.last_balance(addition).blank?
      amount_from_addition
    else
      amount_from_previous_balances
    end
  end

  def amount_from_addition
    return -addition.balance if addition.amount > addition.balance && addition.balance > 0
    -addition.amount
  end

  def amount_from_previous_balances
    return 0 unless sum > 0 && sum < addition.amount
    - (addition.amount - sum)
  end

  def sum
    addition.amount - (previous_balance - positive_amounts)
  end

  def previous_balance
    employee_balance.previous_balances.last.try(:balance).to_i
  end

  def positive_amounts
    employee_balance.positive_balances(addition) +
      + employee_balance.active_balances.pluck(:amount).sum
  end
end

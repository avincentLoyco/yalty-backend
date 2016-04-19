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
        employee_balance.time_off_category_id, employee_balance.now_or_effective_at
      )
    return false unless join_model_time_off_policy
    join_model_time_off_policy.time_off_policy.counter?
  end

  def calculate_counter_amount
    0 - previous_balance.to_i
  end

  def calculate_balancer_amount
    if last_balance_after_addition.blank?
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

  def positive_amounts
    positive_balance_after_addition + active_balances.pluck(:amount).sum
  end

  def amount_difference
    return 0 unless addition.amount < addition.balance
    addition.balance - addition.amount
  end

  def active_balances
    RelativeEmployeeBalancesFinder.new(employee_balance).active_balances
  end

  def previous_balance
    RelativeEmployeeBalancesFinder.new(employee_balance).previous_balances.last.try(:balance).to_i
  end

  def last_balance_after_addition
    RelativeEmployeeBalancesFinder
      .new(employee_balance)
      .previous_balances
      .where('amount <= ? AND effective_at > ?', 0, addition.effective_at)
      .last
  end

  def positive_balance_after_addition
    RelativeEmployeeBalancesFinder
      .new(employee_balance)
      .balances_related_by_category_and_employee
      .where(
        effective_at: addition.effective_at..employee_balance.now_or_effective_at,
        amount: 1..Float::INFINITY,
        validity_date: nil
      )
      .pluck(:amount).sum
  end
end

class CalculateEmployeeBalanceRemovalAmount
  def initialize(removal)
    @removal = removal
    @additions = removal.balance_credit_additions
    @amount_to_expire = calculate_amount_to_expire
    @first_addition = additions.order(:effective_at).first || additions.first
  end

  def call
    return 0 unless removal.present? && additions.present?
    if active_time_off_policy.counter?
      calculate_amount_for_counter
    else
      calculate_amount_for_balancer
    end
  end

  private

  attr_reader :removal, :additions, :amount_to_expire, :first_addition

  def calculate_amount_for_counter
    previous_balance =
      RelativeEmployeeBalancesFinder.new(removal).previous_balances.last.try(:balance).to_i
    0 - previous_balance.to_i
  end

  def calculate_amount_for_balancer
    if last_balance_after_addition.blank?
      amount_from_first_addition
    else
      amount_from_previous_balances
    end
  end

  def calculate_amount_to_expire
    additions.pluck(:manual_amount, :resource_amount).flatten.select { |value| value > 0 }.sum
  end

  def amount_from_first_addition
    if first_addition.amount > first_addition.balance && first_addition.balance >= 0
      -first_addition.balance
    else
      -first_addition.amount
    end
  end

  def amount_from_previous_balances
    return 0 unless sum >= 0 && sum < amount_to_expire
    - (amount_to_expire - sum)
  end

  def sum
    amount_to_expire -
      (previous_balance - positive_amounts - amount_difference + time_off_in_period_end_amount)
  end

  def positive_amounts
    balances_in_removal_period
      .where('validity_date > ? OR validity_date IS NULL', removal.effective_at)
      .pluck(:resource_amount, :manual_amount).flatten.select { |value| value > 0 }.sum
  end

  def amount_difference
    return 0 unless first_addition.amount > first_addition.balance
    first_addition.balance - first_addition.amount
  end

  def time_off_in_period_end_amount
    time_off_in_period =
      TimeOff
      .for_employee_in_category(removal.employee_id, removal.time_off_category_id)
      .where('start_time < ? AND end_time > ?', removal.effective_at, removal.effective_at)
      .first
    return 0 unless time_off_in_period.present?
    time_off_in_period.balance(nil, removal.effective_at.end_of_day)
  end

  def previous_balance
    RelativeEmployeeBalancesFinder.new(removal).previous_balances.last.try(:balance).to_i
  end

  def active_time_off_policy
    removal
      .employee
      .active_policy_in_category_at_date(removal.time_off_category_id, additions.first.effective_at)
      .time_off_policy
  end

  def last_balance_after_addition
    balances_in_removal_period.where.not(id: [first_addition.id, removal.id])
  end

  def balances_in_removal_period
    Employee::Balance
      .employee_balances(removal.employee_id, removal.time_off_category_id)
      .where('effective_at BETWEEN ? AND ?', first_addition.effective_at, removal.effective_at)
  end
end

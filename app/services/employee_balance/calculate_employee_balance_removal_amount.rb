class CalculateEmployeeBalanceRemovalAmount
  def initialize(removal)
    @removal = removal
    @additions = removal.balance_credit_additions
    @amount_to_expire = calculate_amount_to_expire
    @first_addition = additions.order(:effective_at).first
  end

  def call
    return 0 unless removal.present? && additions.present?
    if removal.employee_time_off_policy.time_off_policy.counter?
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
    # if last_balance_after_addition.blank?
    #   amount_from_addition
    # else
    amount_from_previous_balances
    # end
    # return 0 unless amount_to_expire > used_amounts
    # - (amount_to_expire - used_amounts)
  end

  def calculate_amount_to_expire
    additions.pluck(:manual_amount, :resource_amount).flatten.select { |value| value > 0 }.sum
  end

  def amount_from_addition
    0
  end

  def amount_from_previous_balances
    return 0 unless sum > 0 && sum < amount_to_expire
    - (amount_to_expire - sum)
  end

  def sum
    amount_to_expire -
      (previous_balance - positive_amounts - amount_difference - time_off_in_period_amount)
  end

  def positive_amounts
    additions =
      Employee::Balance
      .where(time_off_category_id: removal.time_off_category, employee: removal.employee)
      .where('effective_at BETWEEN ? AND ? AND validity_date > ?',
              first_addition.effective_at, removal.effective_at, removal.effective_at
      )
    additions.pluck(:resource_amount, :manual_amount).flatten.select { |value| value > 0 }.sum
  end

  def amount_difference
    return 0 unless first_addition.amount < first_addition.balance
    first_addition.balance - first_addition.amount
  end

  def time_off_in_period_amount
    time_off_in_period =
      TimeOff
      .where(employee: removal.employee, time_off_category: removal.time_off_category)
      .where('start_time < ? AND end_time > ?', removal.effective_at, removal.effective_at)
      .first
    return 0 unless time_off_in_period.present?
    - time_off_in_period.balance(nil, removal.effective_at.end_of_day)
  end

  def previous_balance
    RelativeEmployeeBalancesFinder.new(removal).previous_balances.last.try(:balance).to_i
  end
end

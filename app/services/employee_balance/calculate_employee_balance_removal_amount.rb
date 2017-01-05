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
    amount = amount_from_previous_balances
    if removal.manual_amount != 0 && removal.effective_at == removal.validity_date
      amount -= removal.manual_amount
    end

    amount
  end

  def calculate_amount_to_expire
    additions_amounts =
      additions.map { |addition| [addition[:manual_amount], addition[:resource_amount]] }
    additions_amounts.flatten.select { |value| value > 0 }.sum
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
    return 0 unless time_off_in_period_end.present?
    end_of_removal_day = (removal.effective_at + 1.day).beginning_of_day
    end_time =
      if time_off_in_period_end.end_time < end_of_removal_day
        time_off_in_period_end.end_time
      else
        end_of_removal_day
      end
    time_off_in_period_end.balance(nil, end_time)
  end

  def time_off_in_period_end
    TimeOff
      .for_employee_in_category(removal.employee_id, removal.time_off_category_id)
      .find_by(
        'start_time <= ? AND end_time > ?',
        removal.effective_at.end_of_day, removal.effective_at
      )
  end

  def previous_balance
    previous_balances = RelativeEmployeeBalancesFinder.new(removal).previous_balances
    return 0 unless previous_balances.last.present?
    if previous_balances.last.time_off_id.present? || time_off_in_period_end.blank?
      previous_balances.last.balance
    else
      related_amount_sum =
        previous_balances
        .where('effective_at >= ?', time_off_in_period_end.start_time)
        .map(&:related_amount).sum
      previous_balances.last.balance - related_amount_sum
    end
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
      .where('effective_at BETWEEN ? AND ? AND id != ?',
        first_addition.effective_at,
        removal.effective_at,
        removal.id)
  end
end

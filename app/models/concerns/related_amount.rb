require 'active_support/concern'

module RelatedAmount
  extend ActiveSupport::Concern

  def related_amount
    return related_amount_at_time_off_end_date if time_off.present?
    return 0 unless time_off_containing_this_balance.present?
    calculate_related_amount * -1
  end

  private

  def related_amount_at_time_off_end_date
    employee
      .employee_balances
      .in_category(time_off_category_id).not_time_off
      .where(
        'employee_balances.effective_at BETWEEN ? AND ?', time_off.start_time, time_off.end_time
      ).inject(0) { |sum, balance| sum + balance.related_amount.abs }
  end

  def calculate_related_amount
    return calculate_time_off_balance(nil, effective_at.end_of_day) unless previous_balance.present?
    calculate_time_off_balance(previous_balance.effective_at.end_of_day, effective_at.end_of_day)
  end

  def previous_balance
    @previous_balance ||=
      employee
      .employee_balances.in_category(time_off_category_id)
      .not_time_off
      .where(
        'employee_balances.effective_at >= ? AND employee_balances.effective_at < ?',
        time_off_containing_this_balance.start_time,
        effective_at
      ).order(:effective_at)
      .last
  end

  def time_off_containing_this_balance
    @time_off_containing_this_balance ||=
      employee
      .time_offs
      .in_category(time_off_category_id)
      .where('? BETWEEN time_offs.start_time AND time_offs.end_time', effective_at)
      .first
  end

  def calculate_time_off_balance(start_time, end_time)
    CalculateTimeOffBalance.new(time_off_containing_this_balance, start_time, end_time).call
  end
end

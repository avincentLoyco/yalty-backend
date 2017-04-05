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
    balances = employee.employee_balances.in_category(time_off_category_id).not_time_off
                       .where(
                         'employee_balances.effective_at::date BETWEEN ? AND ?',
                         time_off.start_time.to_date, time_off.end_time.to_date
                       ).where(
                         'employee_balances.effective_at::date BETWEEN ? AND ?',
                         time_off.start_time.to_date, time_off.end_time.to_date
                       )
    not_removals =
      balances
      .not_removals
      .inject(0) { |sum, balance| sum + balance.related_amount.abs }
    removals =
      balances
      .removals
      .inject(0) { |sum, balance| sum + balance.related_amount.abs }
    not_removals + removals
  end

  def calculate_related_amount
    time_off = time_off_containing_this_balance
    counter_adition_or_balancer_removal =
      (time_off_policy.counter? && time_off.nil? || balance_credit_additions.any?)
    end_time =
      if counter_adition_or_balancer_removal
        if time_off.end_time.to_date > effective_at.to_date
          effective_at.beginning_of_day
        else
          time_off.end_time
        end
      else
        effective_at
      end
    return calculate_time_off_balance(nil, end_time) unless previous_balance.present?
    if previous_balance.balance_credit_additions.any?
      start_of_date_after_removal = (previous_balance.effective_at + 1.day).beginning_of_day
      return calculate_time_off_balance(start_of_date_after_removal, end_time)
    end
    calculate_time_off_balance(previous_balance.effective_at, end_time)
  end

  def previous_balance
    balances_in_category_and_not_time_off =
      employee.employee_balances.in_category(time_off_category_id).not_time_off
    previous_balance =
      balances_in_category_and_not_time_off
      .where(
        'employee_balances.effective_at >= ? AND employee_balances.effective_at < ?',
        time_off_containing_this_balance.start_time,
        effective_at
      ).order(:effective_at)
      .last
    return previous_balance if previous_balance.present?
    return unless previous_balance.nil?
    balances_in_category_and_not_time_off
      .removals
      .where(
        'employee_balances.effective_at::date = ? AND employee_balances.effective_at < ?',
        time_off_containing_this_balance.start_time.to_date,
        effective_at
      ).order(:effective_at)
      .last
  end

  def time_off_containing_this_balance
    @time_off_containing_this_balance ||=
      employee
      .time_offs
      .in_category(time_off_category_id)
      .where('? BETWEEN time_offs.start_time::date AND
              time_offs.end_time::date AND
              time_offs.end_time > ?', effective_at.to_date, effective_at)
      .first
  end

  def calculate_time_off_balance(start_time, end_time)
    CalculateTimeOffBalance.new(time_off_containing_this_balance, start_time, end_time).call
  end
end

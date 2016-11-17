class CalculatePeriodOverview
  def initialize(period, employee_id, time_off_category_id)
    @employee_id = employee_id
    @time_off_category_id = time_off_category_id
    @period = period
    @period_start_balance = period_start_balance
  end

  def call
    periods_positive_amount =
      positive_amounts_between(@period[:start_date], @period[:end_date])
    negative_amounts =
      negative_amounts_between(
        @period[:start_date],
        end_date_for_negative_values,
        @period[:end_date]
      )
    amount_taken = @period_start_balance + negative_amounts
    amount_taken =
      if @period[:type] == 'balancer' && amount_taken.abs > periods_positive_amount.abs
        - periods_positive_amount
      else
        amount_taken
      end
    period_result = periods_positive_amount + amount_taken
    if @period[:type].eql?('balancer')
      period_result = 0 unless period_result > 0
    end
    {
      amount_taken: amount_taken.abs,
      period_result: period_result,
      balance: @period[:type].eql?('balancer') ? last_balance_value_in_period : amount_taken
    }
  end

  private

  def end_of_period_time_off_amount
    if @period[:type].eql?('balancer')
      - time_off_amount_from_till(last_balance_in_period.effective_at, @period[:validity_date])
    else
      - time_off_amount_from_till(last_balance_in_period.effective_at, @period[:end_date])
    end
  end

  def last_balance_in_period
    @balance ||= balances.between(@period[:start_date], @period[:end_date])
                         .order(:effective_at)
                         .last
  end

  def last_balance_value_in_period
    time_off = last_time_off_between(@period[:start_date], @period[:end_date])
    return 0 unless last_balance_in_period || time_off
    value = last_balance_in_period.try(:balance).to_i
    if time_off.present?
      time_off_end_time = (@period[:end_date] + 1.day).beginning_of_day
      value - CalculateTimeOffBalance.new(time_off, nil, time_off_end_time).call
    else
      value
    end
  end

  def end_date_for_negative_values
    @period[:type] == 'balancer' ? @period[:validity_date] : @period[:end_date]
  end

  def balances
    @balances ||= Employee::Balance.employee_balances(@employee_id, @time_off_category_id)
  end

  def period_addition
    balances
      .between(@period[:start_date], @period[:end_date])
      .where(policy_credit_addition: true)
      .order(:effective_at)
      .first
  end

  def period_start_balance
    return 0 unless period_addition.present?

    if @period[:type].eql?('balancer')
      period_addition.balance - period_addition.amount
    else
      period_addition.balance.abs
    end
  end

  def positive_amounts_between(from_date, to_date)
    manual_and_resource_amounts =
      balances.between(from_date, to_date).pluck(:manual_amount, :resource_amount)
    additions_sum = manual_and_resource_amounts.flatten.select { |value| value > 0 }.sum

    return additions_sum if @period[:type].eql?('balancer')
    additions_sum - period_addition.resource_amount
  end

  def negative_amounts_between(from_date, time_offs_to_date, removals_to_date)
    manual_and_resource_amounts = balances.not_removals.between(from_date, time_offs_to_date)
                                          .pluck(:manual_amount, :resource_amount)
    negative_amounts = manual_and_resource_amounts.flatten.select { |value| value < 0 }.sum
    removal_amount_sum =
      balances.removals.between(from_date, removals_to_date)
              .pluck(:manual_amount, :resource_amount).flatten.sum
    negative_amounts + removal_amount_sum + end_of_period_time_off_amount
  end

  def last_time_off_between(start_date, end_date)
    TimeOff
      .for_employee_in_category(@employee_id, @time_off_category_id)
      .where('start_time >= ? AND end_time > ? AND start_time::date <= ?',
        start_date, end_date, end_date)
      .first
  end

  def time_off_amount_from_till(start_date, end_date)
    time_off = last_time_off_between(start_date, end_date)

    return 0 unless time_off
    end_date_end_time = (end_date + 1.day).beginning_of_day
    next_day_of_end_date_beginning =
      time_off.end_time < end_date_end_time ? time_off.end_time : end_date_end_time
    CalculateTimeOffBalance.new(time_off, nil, next_day_of_end_date_beginning).call
  end
end

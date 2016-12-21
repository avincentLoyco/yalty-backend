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
        end_date_for_negative_values
      )
    amount_taken = @period_start_balance + negative_amounts
    amount_taken = calculate_amount_taken(amount_taken, periods_positive_amount)
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
    if @period[:type].eql?('balancer') && @period[:validity_date]
      - time_off_amount_from_till(last_balance_in_period.effective_at, @period[:validity_date])
    else
      amount =
        if last_balance_in_period && last_balance_in_period.time_off_id.nil?
          last_balance_in_period.related_amount + time_off_value(last_balance_in_period)
        else
          0
        end
      amount - time_off_amount_from_till(last_balance_in_period.effective_at, @period[:end_date])
    end
  end

  def last_balance_in_period
    @balance ||=
      balances
      .where('effective_at::date BETWEEN ? AND ?', @period[:start_date], @period[:end_date])
      .order(:effective_at)
      .last
  end

  def last_balance_value_in_period
    time_off = last_time_off_between(@period[:start_date], @period[:end_date])
    return 0 unless last_balance_in_period || time_off
    value = last_balance_in_period.try(:balance).to_i
    if time_off.present?
      time_off_end_time = (@period[:end_date] + 1.day).beginning_of_day
      date =
        if last_balance_in_period.effective_at > time_off.start_time
          last_balance_in_period.effective_at.beginning_of_day
        else
          time_off.start_time
        end
      value - CalculateTimeOffBalance.new(time_off, date, time_off_end_time).call
    else
      value
    end
  end

  def end_date_for_negative_values
    if @period[:type] == 'balancer' && @period[:validity_date]
      @period[:validity_date]
    else
      @period[:end_date]
    end
  end

  def balances
    @balances ||= Employee::Balance.employee_balances(@employee_id, @time_off_category_id)
  end

  def period_addition
    @period_addition ||=
      balances
      .where('effective_at::date BETWEEN ? AND ?', @period[:start_date], @period[:end_date])
      .order(:effective_at)
      .first
  end

  def period_start_balance
    return 0 unless period_addition.present?

    if @period[:type].eql?('balancer')
      period_addition.balance - period_addition.resource_amount - period_addition.manual_amount
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

  def negative_amounts_between(from_date, time_offs_to_date)
    negative_balances = balances.between(from_date, time_offs_to_date)
    if @period[:type] == 'balancer' && @period[:validity_date]
      negative_balances =
        negative_balances.where.not(effective_at: period_addition.validity_date)
    end
    manual_and_resource_amounts = negative_balances.pluck(:manual_amount, :resource_amount)
    negative_amounts = manual_and_resource_amounts.flatten.select { |value| value < 0 }.sum
    negative_amounts + end_of_period_time_off_amount - related_amount_at_period_beginning
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

  def related_amount_at_period_beginning
    time_off_at_start =
      TimeOff.where(
        'start_time::date < ? AND end_time::date >= ?', @period[:start_date], @period[:start_date]
      ).first
    return 0 unless time_off_at_start.present? && @period[:type].eql?('balancer')
    time_off_at_start.balance(nil, @period[:start_date].beginning_of_day)
  end

  def time_off_value(balance)
    time_off = last_time_off_between(@period[:start_date], @period[:end_date])
    return 0 unless time_off && @period[:type].eql?('balancer')
    time_off
      .balance(balance.effective_at.beginning_of_day, (@period[:end_date] + 1.day).beginning_of_day)
  end

  def calculate_amount_taken(amount_taken, periods_positive_amount)
    return 0 if amount_taken >= 0
    if @period[:type].eql?('balancer') && amount_taken.abs > periods_positive_amount.abs
      - periods_positive_amount
    else
      amount_taken
    end
  end
end

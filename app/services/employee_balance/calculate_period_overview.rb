class CalculatePeriodOverview
  def initialize(period, employee_id, time_off_category_id)
    @employee_id = employee_id
    @time_off_category_id = time_off_category_id
    @period = period
    @period_start_balance = period_start_balance
  end

  def call
    periods_positive_amount = positive_amounts_between
    negative_amounts = negative_amounts_between
    if @period[:type].eql?('balancer') && @period[:validity_date].present?
      amount_taken = -amount_taken_from_removal(periods_positive_amount)
    else
      amount_taken = period_start_balance + negative_amounts
      amount_taken = calculate_amount_taken(amount_taken, periods_positive_amount)
    end
    period_result = periods_positive_amount + amount_taken
    period_result = 0 if period_result.negative? && @period[:type].eql?('balancer')
    {
      amount_taken: amount_taken.abs,
      period_result: period_result,
      balance: @period[:type].eql?('balancer') ? last_balance_value_in_period : amount_taken
    }
  end

  private

  def amount_taken_from_removal(positive_amounts)
    removal = period_balances.map(&:balance_credit_removal).compact.uniq.first
    return positive_amounts if removal.resource_amount >= 0
    return positive_amounts + removal.resource_amount if removal.balance_type.eql?('removal')
    next_periods_positives =
      positive_amounts_between(
        balances
          .between(@period[:end_date], removal.effective_at)
          .where.not(id: period_end.try(:id))
      )
    if (removal.resource_amount + next_periods_positives).abs >= positive_amounts
      0
    elsif (removal.resource_amount + next_periods_positives).positive?
      positive_amounts
    else
      positive_amounts + (removal.resource_amount + next_periods_positives)
    end
  end

  def end_of_period_time_off_amount
    amount =
      if last_balance_in_period && last_balance_in_period.time_off_id.nil?
        last_balance_in_period.related_amount + time_off_value(last_balance_in_period)
      else
        0
      end
    amount - time_off_amount_from_till(last_balance_in_period.effective_at, @period[:end_date])
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

  def period_start_balance
    return 0 unless period_addition.present?
    if @period[:type].eql?('balancer')
      period_addition.balance - period_addition.resource_amount - period_addition.manual_amount
    else
      period_addition.balance.abs
    end
  end

  def positive_amounts_between(balances_to_filter = period_balances)
    if @period[:type].eql?('balancer')
      balances_to_filter.pluck(:manual_amount, :resource_amount)
    else
      balances_to_filter.pluck(:manual_amount)
    end.flatten.select(&:positive?).sum
  end

  def negative_amounts_between
    negative_balances =
      balances.where.not(balance_type: 'removal').between(@period[:start_date], @period[:end_date])
    manual_and_resource_amounts = negative_balances.pluck(:manual_amount, :resource_amount)
    negative_amounts = manual_and_resource_amounts.flatten.select(&:negative?).sum
    negative_amounts + end_of_period_time_off_amount - related_amount_at_period_beginning
  end

  def last_time_off_between(start_date, end_date)
    TimeOff
      .for_employee_in_category(@employee_id, @time_off_category_id)
      .find_by('start_time >= ? AND end_time > ? AND start_time::date <= ?',
        start_date, end_date, end_date)
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
    return 0 unless time_off_at_start.present?
    time_off_at_start.balance(nil, @period[:start_date].beginning_of_day)
  end

  def time_off_value(balance)
    time_off = last_time_off_between(@period[:start_date], @period[:end_date])
    return 0 unless time_off && @period[:type].eql?('balancer')
    balance.related_amount
  end

  def calculate_amount_taken(amount_taken, periods_positive_amount)
    return 0 if amount_taken >= 0
    if @period[:type].eql?('balancer') && amount_taken.abs > periods_positive_amount.abs
      - periods_positive_amount
    else
      amount_taken
    end
  end

  def period_balances
    @period[:end_date] =
      if @period[:start_date].eql?(@period[:end_date])
        @period[:end_date] += 1
      else
        @period[:end_date]
      end
    balances_in_period = balances.between(@period[:start_date], @period[:end_date]).pluck(:id)
    period_start =
      balances
      .where(balance_type: 'end_of_period')
      .find_by('effective_at::date = ?', @period[:start_date]).try(:id)

    balances
      .where(id: [balances_in_period, period_end.try(:id)].compact.flatten)
      .where.not(id: period_start)
  end

  def balances
    @balances ||= Employee::Balance.for_employee_and_category(@employee_id, @time_off_category_id)
  end

  def period_addition
    @period_addition ||= period_balances.order(:effective_at).first
  end

  def last_balance_in_period
    @balance ||= period_balances.order(:effective_at).last
  end

  def period_end
    @period_end ||=
      balances
      .where(balance_type: 'end_of_period')
      .find_by('effective_at::date = ?', @period[:end_date] + 1.day)
  end
end

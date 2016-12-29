class OverrideAmountTakenForBalancer
  attr_reader :periods

  def initialize(periods)
    @periods = periods
  end

  def call
    return periods unless periods.first[:type].eql?('balancer') && !periods.first[:validity_date]
    override_amount_for_periods
  end

  private

  def override_amount_for_periods
    periods.map.each_with_index do |period, index|
      next if period[:period_result].eql?(0) || periods[index + 1].blank?
      if periods[index + 1][:amount_taken] > 0
        use_whole_period_amount(period)
      else
        next if previous_period(index).present? && previous_period(index)[:period_result].nonzero?
        iterate_over_next_periods_to_remove_amount(period, index)
      end
    end
    periods
  end

  def previous_period(index)
    index.nonzero? ? periods[index - 1] : []
  end

  def use_whole_period_amount(period)
    period[:amount_taken] += period[:period_result]
    period[:period_result] = 0
  end

  def periods_after(index)
    periods[(index + 1)..periods.length]
  end

  def periods_difference(index, next_period, next_index)
    periods_sum = periods[index + 1..next_index].map { |p| p[:period_result] }.sum
    next_period[:balance] - next_period[:period_result] - periods_sum
  end

  def difference(period)
    return 0 if period[:balance].eql?(period[:period_result])
    period[:balance] - period[:period_result] - period[:amount_taken]
  end

  def balance_didnt_changed?(index, next_period, next_index)
    (next_period[:balance] - next_period[:period_result])
      .eql?(periods_after(index)[next_index - 1][:balance])
  end

  def iterate_over_next_periods_to_remove_amount(period, index)
    periods_after(index).each_with_index do |next_period, next_index|
      if periods_difference(index, next_period, next_index) < 0
        use_whole_period_amount(period)
      else
        next if balance_didnt_changed?(index, next_period, next_index)
        difference = difference(period)
        period[:period_result] = periods_difference(index, next_period, next_index)
        period[:amount_taken] = period[:amount_taken] + period[:balance] - period[:period_result]
        period[:amount_taken] -= difference if difference.nonzero? && difference > 0
      end
    end
  end
end

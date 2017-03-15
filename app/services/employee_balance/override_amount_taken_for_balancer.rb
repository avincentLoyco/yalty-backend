class OverrideAmountTakenForBalancer
  attr_reader :periods, :already_added_amount, :balance_difference

  def initialize(periods)
    @periods = periods
    @already_added_amount = 0
    @balance_difference = 0
  end

  def call
    return periods unless periods.first[:type].eql?('balancer') && !periods.first[:validity_date]
    override_amount_for_periods
  end

  private

  def override_amount_for_periods
    @balance_difference = periods.map { |p| p[:period_result] }.sum - periods.last[:balance]
    periods.map.each_with_index do |period, index|
      next if period[:period_result].eql?(0) || periods[index + 1].blank?
      if periods[index + 1][:amount_taken].positive?
        use_whole_period_amount(period)
      else
        next if previous_period(index).present? && previous_period(index)[:period_result].nonzero?
        iterate_over_next_periods_to_remove_amount(period)
      end
    end
    periods
  end

  def previous_period(index)
    index.nonzero? ? periods[index - 1] : []
  end

  def use_whole_period_amount(period)
    previous_amount = period[:amount_taken]
    period[:amount_taken] += period[:period_result]
    period[:period_result] = 0
    @already_added_amount += previous_amount - period[:amount_taken]
  end

  def iterate_over_next_periods_to_remove_amount(period)
    if balance_difference + already_added_amount > period[:period_result]
      use_whole_period_amount(period)
    else
      previous_result = period[:period_result]
      previous_amount = period[:amount_taken]
      period[:period_result] = period[:period_result] - (balance_difference + already_added_amount)
      period[:amount_taken] = previous_result - period[:period_result] + previous_amount
      @already_added_amount += previous_amount - period[:amount_taken]
    end
  end
end

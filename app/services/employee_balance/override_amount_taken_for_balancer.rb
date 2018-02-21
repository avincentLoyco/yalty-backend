class OverrideAmountTakenForBalancer
  attr_reader :periods, :already_added_amount, :balance_difference, :contract_periods

  def initialize(periods, contract_periods)
    @periods = periods
    @already_added_amount = 0
    @balance_difference = 0
    @contract_periods = contract_periods
  end

  def call
    return periods unless periods.first[:type].eql?("balancer") && !periods.first[:validity_date]
    override_amount_for_periods
  end

  private

  def override_amount_for_periods
    @balance_difference = find_balance_difference
    periods.map.each_with_index do |period, index|
      next_index = index + 1
      next if period[:period_result].eql?(0) || periods[next_index].blank? ||
          contract_end_index.present? && next_index.eql?(contract_end_index)

      if periods[next_index][:amount_taken].positive?
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

  def find_balance_difference
    if periods_in_the_same_contract_dates?
      periods.map { |p| p[:period_result] }.sum - periods.last[:balance]
    else
      balance_difference_from_contract_end
    end
  end

  def periods_in_the_same_contract_dates?
    contract_periods.any? do |period|
      period.include?(periods.first[:start_date].to_date) &&
        period.include?(periods.last[:start_date].to_date)
    end
  end

  def contract_end_index
    contract_end =
      contract_periods.select do |period|
        period.last.is_a?(Date) && period.last < periods.last[:start_date]
      end.last

    return unless contract_end.present?

    first_after_contract_end = periods.select { |p| p[:start_date] > contract_end.last }.first
    periods.index(first_after_contract_end)
  end

  def balance_difference_from_contract_end
    first_period_before_index = contract_end_index - 1
    periods[0..first_period_before_index].map { |p| p[:period_result] }.sum -
      periods[first_period_before_index][:balance]
  end
end

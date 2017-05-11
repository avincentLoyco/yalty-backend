class RelatedPolicyPeriod
  attr_reader :related_policy, :effective_at, :time_off_policy

  delegate :start_day, :start_month, :years_to_effect, :end_day, :end_month, to: :time_off_policy

  def initialize(related_policy)
    @related_policy = related_policy
    @effective_at = related_policy.effective_at
    @time_off_policy = related_policy.time_off_policy
  end

  def last_start_date_before(date)
    return related_policy.effective_at.to_date unless related_policy.not_reset?
    years_to_remove = (date.year - first_start_date.year) % policy_length
    last_start_date = Date.new(date.year - years_to_remove.years, start_month, start_day)

    if last_start_date > date
      last_start_date - policy_length.years
    elsif last_start_date == date
      previous_start = last_start_date - policy_length.years
      related_policy.effective_at > previous_start ? related_policy.effective_at : previous_start
    else
      last_start_date
    end
  end

  def policy_length
    years_to_effect && years_to_effect > 1 ? years_to_effect : 1
  end

  def first_start_date
    return related_policy.effective_at unless related_policy.not_reset?
    start_year_date = Date.new(effective_at.year, start_month, start_day)
    effective_at > start_year_date ? start_year_date + 1.year : start_year_date
  end

  def last_start_date
    years_before = (Time.zone.today.year - first_start_date.year) % policy_length
    last_date = Date.new(Time.zone.today.year - years_before, start_month, start_day)
    last_date > Time.zone.today ? last_date - policy_length.years : last_date
  end

  def end_date
    last_start_date + policy_length.years
  end

  def previous_start_date
    return last_start_date - policy_length.years if related_policy.not_reset?
    last_start_date
  end

  def last_validity_date
    return unless end_month && end_day && years_to_effect
    Date.new(last_start_date.year + years_to_effect, end_month, end_day)
  end

  def first_validity_date
    return unless end_month && end_day && years_to_effect
    Date.new(first_start_date.year + years_to_effect, end_month, end_day)
  end

  def validity_date_for_balance_at(date, balance_type = 'addition')
    return unless end_date?
    validity_date =
      if %w(addition assignation).include?(balance_type) && in_start_date?(date)
        validity_date_for_period_start(date)
      else
        validity_date_for_period_time(date, balance_type)
      end
    verify_with_contract_periods(date, validity_date, balance_type)
  end

  def verify_with_contract_periods(date, validity_date, balance_type)
    no_period_with_dates =
      related_policy.employee.contract_periods.none? do |period|
        period.include?(validity_date.to_date) && period.include?(date.to_date) &&
          !(balance_type.eql?('end_of_period') && period.first.eql?(date.to_date))
      end
    return validity_date unless no_period_with_dates
    contract_end_for(date, validity_date, balance_type)
  end

  def validity_date_for_period_start(date)
    validity_date =
      Date.new(
        date.year + years_to_effect, end_month, end_day
      ) + 1.day + Employee::Balance::REMOVAL_OFFSET
    years_end_date = Date.new(date.year, end_month, end_day)
    validity_date += 1.year if date.to_date > years_end_date
    validity_date += 1.year if (validity_date.to_date - date.to_date).to_i / 365 < years_to_effect
    validity_date
  end

  def validity_date_for_period_time(date, balance_type)
    start_date = Date.new(date.year, start_month, start_day)
    if date.to_date <= start_date && years_to_effect.positive? && !balance_type.eql?('time_off')
      start_date -= 1.year
    end
    validity_date = validity_date_for_period_start(start_date)
    validity_date += 1.year if validity_date < date
    validity_date
  end

  def previous_addition(date)
    related_policy
      .employee_balances
      .where(balance_type: %w(addition assignation))
      .where('effective_at < ?', date)
      .order(:effective_at)
      .last
  end

  def end_date?
    time_off_policy.end_day.present? && time_off_policy.end_month.present? &&
      time_off_policy.years_to_effect.present?
  end

  def contract_end_for(date, validity_date, balance_type)
    periods = related_policy.employee.contract_periods
    previous_periods =
      periods.select { |period| period.last.is_a?(Date) && period.last < validity_date.to_date }
    return validity_date unless previous_periods.present?
    contract_end = previous_periods.last.last + 1.day + Employee::Balance::RESET_OFFSET
    if contract_end > validity_date || (balance_type.eql?('assignation') &&
        (date.eql?(contract_end.to_date) || related_policy.effective_at > contract_end.to_date))
      validity_date
    else
      contract_end
    end
  end

  def in_start_date?(date)
    time_off_policy.start_day.eql?(date.day) && time_off_policy.start_month.eql?(date.month)
  end
end

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

  def validity_date_for(date)
    return unless end_date?
    validity_date =
      Date.new(date.year + years_to_effect, end_month, end_day) + Employee::Balance::REMOVAL_OFFSET
    years_end_date = Date.new(date.year, end_month, end_day)
    validity_date += 1.year if date.to_date > years_end_date
    validity_date += 1.year if (validity_date.to_date - date.to_date).to_i / 365 < years_to_effect
    verify_with_contract_periods(validity_date)
  end

  def validity_date_for_balance_at(date)
    return unless end_date?
    validity_date =
      if previous_addition(date)
        previous_addition(date).validity_date
      else
        related_policy.policy_assignation_balance.validity_date
      end
    validity_date = validity_date >= date ? validity_date : validity_date_for(date)
    verify_with_contract_periods(validity_date)
  end

  def verify_with_contract_periods(validity_date)
    # TODO: Must test if it's the day after end of period for balances that
    # can be the day after contract end at 00:00:0X
    if related_policy.employee
                     .contract_periods.none? { |period| period.include?(validity_date.to_date) }
      contract_end_for(validity_date)
    else
      validity_date
    end
  end

  def previous_addition(date)
    related_policy
      .employee_balances.additions.where('effective_at < ?', date)
      .order(:effective_at)
      .last
  end

  def end_date?
    time_off_policy.end_day.present? && time_off_policy.end_month.present? &&
      time_off_policy.years_to_effect.present?
  end

  def contract_end_for(validity_date)
    contract_end = related_policy.employee
                                 .events.where(event_type: 'contract_end')
                                 .where('effective_at <= ?::date', validity_date)
                                 .reorder('employee_events.effective_at DESC')
                                 .limit(1).pluck(:effective_at).first&.in_time_zone
    return unless contract_end
    contract_end + Employee::Balance::REMOVAL_OFFSET
  end
end

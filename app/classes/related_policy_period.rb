class RelatedPolicyPeriod
  attr_reader :related_policy, :effective_at, :time_off_policy

  delegate :start_day, :start_month, :years_to_effect, :end_day, :end_month, to: :time_off_policy

  def initialize(related_policy)
    @related_policy = related_policy
    @effective_at = related_policy.effective_at
    @time_off_policy = related_policy.time_off_policy
  end

  def last_start_date_before(date)
    years_to_remove = (date.year - first_start_date.year) % policy_length
    last_start_date = Date.new(date.year - years_to_remove.years, start_month, start_day)

    last_start_date > date ? last_start_date - policy_length.years : last_start_date
  end

  def policy_length
    years_to_effect && years_to_effect > 1 ? years_to_effect : 1
  end

  def first_start_date
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
    last_start_date - policy_length.years
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
    return unless end_day && end_month && years_to_effect
    validity_date =
      Date.new(date.year + years_to_effect, end_month, end_day) + Employee::Balance::REMOVAL_SECONDS
    validity_date += 1.year if validity_date < date
    return validity_date if (date.month <= end_month && date.day <= end_day) || years_to_effect == 0
    validity_date + 1.year
  end

  def validity_date_for_balance_at(date)
    return unless end_date?
    validity_date =
      if previous_addition(date)
        previous_addition(date).validity_date
      else
        related_policy.policy_assignation_balance.validity_date
      end
    validity_date >= date ? validity_date : validity_date_for(date)
  end

  def previous_addition(date)
    related_policy
      .employee_balances.additions.where('effective_at < ?', date)
      .order(:effective_at)
      .last
  end

  def end_date?
    time_off_policy.end_day.present? && time_off_policy.end_month.present?
  end
end

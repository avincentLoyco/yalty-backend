require 'policy_period'

module CalculateRelatedTimeOffPeriods
  def policy_length
    time_off_policy.years_to_effect > 1 ? time_off_policy.years_to_effect : 1
  end

  def first_start_date
    start_year_date =
      Date.new(effective_at.year, time_off_policy.start_month, time_off_policy.start_day)
    effective_at > start_year_date ? start_year_date + 1.year : start_year_date
  end

  def last_start_date
    years_before = (Time.zone.today.year - first_start_date.year) % policy_length
    last_date =
      Date.new(
        Time.zone.today.year - years_before, time_off_policy.start_month, time_off_policy.start_day
      )

    last_date > Time.zone.today ? last_date - policy_length.years : last_date
  end

  def end_date
    last_start_date + policy_length.years
  end

  def previous_start_date
    last_start_date - policy_length.years
  end

  def last_validity_date
    return nil unless time_off_policy.end_month && time_off_policy.end_day
    Date.new(
      last_start_date.year + time_off_policy.years_to_effect,
      time_off_policy.end_month,
      time_off_policy.end_day
    )
  end

  def first_validity_date
    return nil unless time_off_policy.end_month && time_off_policy.end_day
    Date.new(
      first_start_date.year + time_off_policy.years_to_effect,
      time_off_policy.end_month,
      time_off_policy.end_day
    )
  end
end

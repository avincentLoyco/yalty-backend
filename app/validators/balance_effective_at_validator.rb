class BalanceEffectiveAtValidator
  class << self
    def validate(balance)
      new(balance).validate
    end
  end

  pattr_initialize :balance

  def validate
    return unless validation_required?

    return if matches_effective_at || matches_end_or_start_top_date
    message = "Must be at TimeOffPolicy  assignations date, end date, start date or the previous"\
      " day to start date"
    balance.errors.add(:effective_at, message)
  end

  private

  def validation_required?
    balance.employee_id.present? && not_time_off? && not_manual_adjustment? && not_reset?
  end

  def not_reset?
    return if balance.employee_time_off_policy.blank?
    !balance.balance_type.eql?("reset") && balance.employee_time_off_policy.not_reset?
  end

  def not_time_off?
    balance.time_off_id.nil?
  end

  def not_manual_adjustment?
    !balance.balance_type.eql?("manual_adjustment")
  end

  def matches_effective_at
    balance.effective_at.to_date == balance.employee_time_off_policy.effective_at
  end

  def matches_end_or_start_top_date
    compare_effective_at_with_time_off_polices_related_dates(
      balance.time_off_policy,
      etop_hash["effective_at"].to_date,
      etop_hash["effective_till"].try(:to_date)
   )
  end

  def compare_effective_at_with_time_off_polices_related_dates(
    time_off_policy,
    etop_effective_at,
    etop_effective_till
  )
    day = balance.effective_at.day
    month = balance.effective_at.month
    year = balance.effective_at.year

    valid_start_day_related =
      check_start_day_related(
        time_off_policy,
        etop_effective_at,
        etop_effective_till,
        year,
        month,
        day
      )
    valid_end_date =
      check_end_date(
        time_off_policy,
        etop_effective_at,
        etop_effective_till,
        year,
        month,
        day
      )

    valid_start_day_related || valid_end_date
  end

  def check_start_day_related(
    time_off_policy,
    etop_effective_at,
    etop_effective_till,
    year,
    month,
    day
  )
    start_day = time_off_policy.start_day
    start_month = time_off_policy.start_month
    year_in_range = year >= etop_effective_at.year &&
      (etop_effective_till.nil? || year <= etop_effective_till.year)
    correct_day_and_month = (day == start_day && month == start_month)
    year_in_range && correct_day_and_month
  end

  def etop_hash
    JoinTableWithEffectiveTill.new(
      EmployeeTimeOffPolicy,
      nil,
      nil,
      nil,
      balance.employee_time_off_policy.id,
      nil
    ).call.first
  end

  def check_end_date(
    time_off_policy,
    etop_effective_at,
    etop_effective_till,
    year,
    month,
    day
  )
    return false unless time_off_policy.end_month && time_off_policy.end_day
    date_in_year = Date.new(year, time_off_policy.end_month, time_off_policy.end_day) + 1.day
    end_day = date_in_year.day
    end_month = date_in_year.month
    start_day = time_off_policy.start_day
    start_month = time_off_policy.start_month

    years_to_effect = years_to_effect_for_check(
      etop_effective_till,
      end_month,
      end_day,
      start_month,
      start_day,
      time_off_policy
    )
    years_to_compare = years_to_effect.eql?(0) ? 1 : years_to_effect
    year_in_range = year >= etop_effective_at.year &&
      (etop_effective_till.nil? || year <= etop_effective_till.year + years_to_compare)
    correct_day_and_month = (day == end_day && month == end_month)
    year_in_range && correct_day_and_month
  end

  def years_to_effect_for_check(
    etop_effective_till,
    end_month,
    end_day,
    start_month,
    start_day,
    time_off_policy
  )
    return if etop_effective_till.blank?
    end_date = Date.new(etop_effective_till.year, end_month, end_day)
    start_date = Date.new(etop_effective_till.year, start_month, start_day)
    etop_effective_at = balance.employee_time_off_policy.effective_at
    end_date_before_start_date = end_date < start_date
    end_date_after_or_equal_start_date = end_date >= start_date
    effective_till_after_or_equal_start_date = etop_effective_till >= start_date
    effective_till_before_start_date = etop_effective_till < start_date

    offset =
      if end_date_before_start_date && effective_till_after_or_equal_start_date
        time_off_policy.years_to_effect + 1
      elsif end_date_after_or_equal_start_date && effective_till_before_start_date
        time_off_policy.years_to_effect - 1
      else
        time_off_policy.years_to_effect
      end

    etop_effective_at <= end_date ? offset : offset + 1
  end
end

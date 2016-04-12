class PolicyPeriod
  attr_reader :employee, :time_off_category_id, :active_related_policy

  def initialize(employee, time_off_category_id)
    @employee = employee
    @time_off_category_id = time_off_category_id
    @active_related_policy = employee.active_related_time_off_policy(time_off_category_id)
  end

  def previous_policy_period
    (previous_start_date...current_start_date)
  end

  def current_policy_period
    (current_start_date...next_start_date)
  end

  def future_policy_period
    (next_start_date...future_start_date)
  end

  def previous_start_date
    previous_start = active_related_policy.previous_start_date
    if active_related_policy.effective_at > previous_start && previous_related_policy
      previous_related_policy.last_start_date
    else
      previous_start
    end
  end

  def current_start_date
    if previous_related_policy && active_related_policy.first_start_date > Time.zone.today
      current_start_date_from_previous
    else
      current_start_date_from_active
    end
  end

  def current_start_date_from_active
    if active_related_policy.last_start_date <= Time.zone.today
      active_related_policy.last_start_date
    else
      active_related_polic.last_start_date - active_related_policy.policy_length
    end
  end

  def current_start_date_from_previous
    if previous_related_policy.last_start_date < active_related_policy.effective_at
      previous_related_policy.last_start_date
    else
      previous_related_policy.previous_start_date
    end
  end

  def next_start_date
    if next_related_policy &&
        next_related_policy.first_start_date < active_related_policy.end_date
      next_related_policy.first_start_date
    else
      active_related_policy.end_date
    end
  end

  def future_start_date
    if future_related_policy && next_related_policy &&
        future_related_policy.first_start_date < next_related_policy.end_date
      future_related_policy.first_start_date
    else
      future_start_date_from_active_or_next
    end
  end

  def future_start_date_from_active_or_next
    if next_related_policy
      next_start_date + next_related_policy.policy_length.years
    else
      next_start_date + active_related_policy.policy_length.years
    end
  end

  def next_related_policy
    @next_related_policy ||= employee.next_related_time_off_policy(time_off_category_id)
  end

  def future_related_policy
    @future_related_policy ||= employee.future_related_time_off_policy(time_off_category_id)
  end

  def previous_related_policy
    @previous_related_policy ||= employee.previous_related_time_off_policy(time_off_category_id)
  end
end

class EmployeePolicyPeriod
  attr_reader :employee, :time_off_category_id, :active_related_policy, :active_policy_period

  def initialize(employee, time_off_category_id)
    @employee = employee
    @time_off_category_id = time_off_category_id
    @active_related_policy = employee.active_policy_in_category_at_date(time_off_category_id)
    @active_policy_period = find_active_policy_period
  end

  def previous_policy_period
    return unless active_policy_period.present?
    (previous_start_date...current_start_date)
  end

  def current_policy_period
    return unless active_policy_period.present?
    (current_start_date...next_start_date)
  end

  def future_policy_period
    (next_start_date...future_start_date)
  end

  def previous_start_date
    return unless active_policy_period.present?
    previous_start = active_policy_period.previous_start_date
    if active_related_policy.effective_at > previous_start && previous_related_policy
      RelatedPolicyPeriod.new(previous_related_policy)
                         .last_start_date_before(active_related_policy.effective_at)
    else
      previous_start
    end
  end

  def current_start_date
    if previous_related_policy && active_policy_period &&
        active_policy_period.first_start_date > Time.zone.today
      current_start_date_from_previous
    else
      current_start_date_from_active
    end
  end

  def current_start_date_from_active
    return unless active_policy_period.present?
    if active_policy_period.last_start_date <= Time.zone.today
      active_policy_period.last_start_date
    else
      active_policy_period.last_start_date - active_policy_period.policy_length
    end
  end

  def current_start_date_from_previous
    previous_policy_period = RelatedPolicyPeriod.new(previous_related_policy)
    if previous_policy_period.last_start_date < active_related_policy.effective_at
      previous_policy_period.last_start_date
    else
      previous_policy_period.previous_start_date
    end
  end

  def next_start_date
    next_policy_period = RelatedPolicyPeriod.new(next_related_policy) if next_related_policy
    if next_policy_first_start_date?(next_policy_period)
      next_policy_period.first_start_date
    else
      active_policy_period.try(:end_date)
    end
  end

  def next_policy_first_start_date?(next_policy_period)
    next_policy_period.present? && (active_policy_period.nil? || active_policy_period.present? &&
      next_policy_period.first_start_date < active_policy_period.end_date)
  end

  def future_start_date
    future_policy_period = RelatedPolicyPeriod.new(future_related_policy) if future_related_policy
    next_policy_period = RelatedPolicyPeriod.new(next_related_policy) if next_related_policy

    if future_policy_period && next_policy_period &&
        future_policy_period.first_start_date < next_policy_period.end_date
      future_policy_period.first_start_date
    else
      future_start_date_from_active_or_next
    end
  end

  def future_start_date_from_active_or_next
    if next_related_policy
      next_start_date + RelatedPolicyPeriod.new(next_related_policy).policy_length.years
    else
      next_start_date + active_policy_period.try(:policy_length).to_i.years
    end
  end

  def previous_related_policy
    @previous_related_policy ||=
      employee.assigned_time_off_policies_in_category(time_off_category_id).second
  end

  def next_related_policy
    @next_related_policy ||=
      employee.not_assigned_time_off_policies_in_category(time_off_category_id).last
  end

  def future_related_policy
    @future_related_policy ||=
      employee.not_assigned_time_off_policies_in_category(time_off_category_id).first
  end

  def find_active_policy_period
    return unless active_related_policy.present?
    RelatedPolicyPeriod.new(active_related_policy)
  end
end

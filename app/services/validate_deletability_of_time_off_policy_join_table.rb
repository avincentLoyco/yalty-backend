class ValidateDeletabilityOfTimeOffPolicyJoinTable
  attr_reader :effective_at, :time_off_policy_id, :category_id, :category_id, :join_model

  def initialize(join_model)
    @join_model = join_model
    @effective_at = join_model.effective_at
    @time_off_policy_id = join_model.time_off_policy_id
    @category_id = join_model.time_off_policy.time_off_category_id
  end

  def call
    case join_model.class.to_s
    when EmployeeTimeOffPolicy.to_s
      verify_employee_time_off_policy
    when WorkingPlaceTimeOffPolicy.to_s
      verify_working_place_time_off_policy
    end
  end

  private

  def verify_employee_time_off_policy
    employee_id = join_model.employee_id
    next_etop =
      etops_for_category_and_employee([employee_id])
      .where('effective_at > ?', effective_at)
      .order(:effective_at)
      .first
    raise_cant_delete if balances_in_range?(employee_id, next_etop.try(:effective_at))
    true
  end

  def verify_working_place_time_off_policy
    working_place_id = join_model.working_place_id
    employee_ids = join_model.working_place.employees.pluck(:id)
    etops_before =
      etops_for_category_and_employee(employee_ids).where('effective_at <= ?', effective_at)
    possible_employee_ids = employee_ids - etops_before.pluck(:employee_id)
    etops_after =
      etops_for_category_and_employee(possible_employee_ids).where('effective_at > ?', effective_at)
    next_effective_at = upper_effective_at_bound(working_place_id)
    verify_existing_balance_for_employees(etops_after, possible_employee_ids, next_effective_at)
  end

  def verify_existing_balance_for_employees(etops_after, possible_employee_ids, next_effective_at)
    possible_employee_ids.each do |id|
      next_etop = etops_after.where(employee_id: id).order(:effective_at).first.try(:effective_at)
      next_policy_for_employee = next_effective_at > next_etop ? next_etop : next_effective_at
      raise_cant_delete if balances_in_range?(id, next_policy_for_employee)
    end
    true
  end

  def raise_cant_delete
    message = "Can't remove #{join_model.class} it has a related balance"
    raise CanCan::AccessDenied.new(message, join_model)
  end

  def balances_in_range?(employee_id, upper_effective_at_bound)
    result =
      Employee::Balance.where(
        'employee_id = ? AND effective_at >=  ? AND time_off_category_id = ?',
        employee_id,
        effective_at,
        category_id
      )
    if upper_effective_at_bound.present?
      result.where('effective_at < ?', upper_effective_at_bound).any?
    else
      result.any?
    end
  end

  def etops_for_category_and_employee(employee_ids)
    EmployeeTimeOffPolicy
      .joins(:time_off_policy)
      .where(
        'time_off_policies.time_off_category_id = ? AND employee_id IN (?)',
        category_id,
        employee_ids
      )
  end

  def upper_effective_at_bound(working_place_id)
    next_wptop =
      WorkingPlaceTimeOffPolicy
      .joins(:time_off_policy)
      .where(
        'time_off_policies.time_off_category_id = ? AND working_place_id = ? AND effective_at > ?',
        category_id, working_place_id, effective_at
      )
      .order(:effective_at)
      .first
    next_wptop.try(:effective_at)
  end
end

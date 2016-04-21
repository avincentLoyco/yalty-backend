class ManageEmployeeBalances
  attr_reader :previous_policy, :related, :current_policy, :resource_policy,
    :previous_resource_policy, :category_id, :resource_period

  def initialize(resource_policy)
    @resource_policy = resource_policy
    @related = find_related
    @category_id = resource_policy.time_off_policy.time_off_category_id
    @previous_resource_policy = related.previous_related_time_off_policy(category_id)
    @previous_policy = previous_resource_policy.try(:time_off_policy)
    @resource_period = RelatedPolicyPeriod.new(resource_policy)
  end

  def call
    return if resource_period.first_start_date > Time.zone.today
    if previous_resource_policy.present? && previous_start_date_equal_current?
      update_balances
    else
      ActiveRecord::Base.transaction do
        destroy_previous_additions
        create_balances
      end
    end
  end

  private

  def previous_start_date_equal_current?
    previous_resource_period = RelatedPolicyPeriod.new(previous_resource_policy)

    previous_resource_period.last_start_date == resource_period.first_start_date ||
      previous_resource_period.previous_start_date == resource_period.first_start_date
  end

  def update_balances
    Employee.where(id: employees_ids).each do |employee|
      resource = employee.last_balance_addition_in_category(category_id)
      next if resource.blank?

      options = { amount: policy_amount, validity_date: resource_period.first_validity_date.to_s }
      resource.balance_credit_removal.destroy! if resource.balance_credit_removal.present?

      PrepareEmployeeBalancesToUpdate.new(resource, options).call
      UpdateBalanceJob.perform_later(resource.id, options)
    end
  end

  def destroy_previous_additions
    balances_ids = Employee.where(id: employees_ids).joins(:employee_balances)
                           .where('employee_balances.policy_credit_addition = true
                              AND effective_at >= ? AND time_off_category_id = ?',
                             resource_policy.effective_at, category_id)
                           .map(&:employee_balance_ids).flatten
    Employee::Balance.where(id: balances_ids).destroy_all
  end

  def create_balances
    Employee.where(id: employees_ids).each do |employee|
      employee_id = employee.id
      account_id = employee.account_id
      amount = policy_amount
      options =
        { policy_credit_addition: true, effective_at: balance_effective_at }.merge(balancer_options)

      CreateEmployeeBalance.new(category_id, employee_id, account_id, amount, options).call
    end
  end

  def employees_ids
    return [related.id] if related.is_a?(Employee)
    resource_policy.affected_employees
  end

  def policy_amount
    resource_policy.time_off_policy.counter? ? 0 : resource_policy.time_off_policy.amount
  end

  def balancer_options
    return {} if resource_policy.time_off_policy.counter?
    { validity_date: resource_period.first_validity_date }
  end

  def balance_effective_at
    resource_period.last_start_date
  end

  def find_related
    return resource_policy.employee if resource_policy.is_a?(EmployeeTimeOffPolicy)
    resource_policy.working_place
  end
end

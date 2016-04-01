class ManageEmployeeBalances
  include EmployeeBalanceUpdate

  attr_reader :previous_policy, :related, :current_policy, :resource_policy,
    :previous_resource_policy, :category_id

  def initialize(resource_policy)
    @resource_policy = resource_policy
    @related = find_related
    @category_id = resource_policy.time_off_policy.time_off_category_id
    @previous_resource_policy = related.previous_related_time_off_policy(category_id)
    @previous_policy = previous_resource_policy.try(:time_off_policy)
  end

  def call
    (update_balances && return) if resource_policy.first_start_date > Date.today
    if previous_resource_policy.present? &&
        previous_resource_policy.previous_start_date <= resource_policy.first_start_date
      update_balances
    else
      ActiveRecord::Base.transaction do
        # LOOK AT removing balances with removal -> crazy border case
        destroy_previous_additions
        create_balances
      end
    end
  end

  private

  def update_balances
    Employee.where(id: employees_ids).each do |employee|
      resource, attributes = find_resource_and_attributes(employee)
      next if resource.blank?
      update_employee_balances(resource, attributes)
    end
  end

  def destroy_previous_additions
    balances_ids = Employee.where(id: employees_ids).joins(:employee_balances)
                           .where('employee_balances.policy_credit_addition = true
                              AND effective_at <= ? AND time_off_category_id = ?',
                             Time.zone.today, category_id).map(&:employee_balance_ids).flatten
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

  def find_resource_and_attributes(employee)
    if previous_resource_policy.present? &&
        previous_resource_policy.previous_start_date == resource_policy.first_start_date
      resource = employee.last_balance_addition_in_category(category_id)
      [resource, { amount: policy_amount }]
    else
      resource = employee.last_balance_before_date(category_id, resource_policy.effective_at)
      [resource, {}]
    end
  end

  def balancer_options
    return {} if resource_policy.time_off_policy.counter?
    { validity_date: resource_policy.end_date }
  end

  def balance_effective_at
    resource_policy.last_start_date
  end

  def find_related
    return resource_policy.employee if resource_policy.is_a?(EmployeeTimeOffPolicy)
    resource_policy.working_place
  end
end

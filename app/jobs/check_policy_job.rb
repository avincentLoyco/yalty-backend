class CheckPolicyJob < ActiveJob::Base
  @queue = :check_policy_job

  def perform
    TimeOffPolicy.all.each do |policy|
      if policy.starts_today? || policy.ends_today?
        policy.policy_type == 'counter' ? manage_counter(policy) : manage_balancer(policy)
      end
    end
  end

  def manage_counter(policy)
    return unless policy.starts_today?
    employees_ids = policy.affected_employees_ids

    employees = Employee.where(id: employees_ids)
    employees.each do |employee|
      category, employee, account, amount, options =  policy.time_off_category_id, employee.id,
        employee.account_id, 0, { policy_credit_addition: true }

      CreateEmployeeBalance.new(category, employee, account, amount, options).call
    end
  end

  def manage_balancer(policy)
    policy.starts_today? ? create_credit_additions(policy) : create_credit_removals(policy)
  end

  def create_credit_additions(policy)
    employees_ids = policy.affected_employees_ids
    policy_addition = policy.amount

    employees = Employee.where(id: employees_ids)
    employees.each do |employee|
      category, employee_id, account, amount, options = policy.time_off_category_id, employee.id,
          employee.account_id, policy_addition, { policy_credit_addition: true }

      CreateEmployeeBalance.new(category, employee_id, account, amount, options).call
    end
  end

  def create_credit_removals(policy)
    employees_ids = policy.affected_employees_ids
    last_policy_addition = policy.last_balance_addition

    employees = Employee.where(id: employees_ids)
    employees.each do |employee|
      last_balance = employee.last_balance_in_category(policy.time_off_category_id)

      if last_balance > last_policy_addition
        category, employee, account, amount, options = policy.time_off_category_id, employee.id,
          employee.account_id, last_policy_addition - last_balance, { policy_credit_removal: true }

        CreateEmployeeBalance.new(category, employee, account, amount, options).call
      end
    end
  end
end

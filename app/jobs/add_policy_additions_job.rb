class AddPolicyAdditionsJob < ActiveJob::Base
  @queue = :add_policy_addition_job

  def perform
    TimeOffPolicy.all.each do |policy|
      if policy.starts_today?
        policy.policy_type == 'counter' ? manage_counter(policy) : manage_balancer(policy)
      end
    end
  end

  private

  def manage_counter(policy)
    employees = Employee.where(id: policy.affected_employees_ids)

    employees.each do |employee|
      category, employee, account, amount, options =
        policy.time_off_category_id, employee.id, employee.account_id, 0,
        { policy_credit_addition: true }

      CreateEmployeeBalance.new(category, employee, account, amount, options).call
    end
  end

  def manage_balancer(policy)
    employees = Employee.where(id: policy.affected_employees_ids)
    policy_addition = policy.amount

    employees.each do |employee|
      category, employee, account, amount, options =
        policy.time_off_category_id, employee.id, employee.account_id, policy_addition,
        { policy_credit_addition: true }

      CreateEmployeeBalance.new(category, employee, account, amount, options).call
    end
  end
end

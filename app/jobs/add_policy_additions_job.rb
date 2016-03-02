class AddPolicyAdditionsJob < ActiveJob::Base
  queue_as :policies_and_balances

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
      category = policy.time_off_category_id
      account = employee.account_id
      amount = counter_amount(policy, employee)
      employee = employee.id
      options = { policy_credit_addition: true }

      CreateEmployeeBalance.new(category, employee, account, amount, options).call
    end
  end

  def manage_balancer(policy)
    employees = Employee.where(id: policy.affected_employees_ids)
    policy_addition = policy.amount

    employees.each do |employee|
      category = policy.time_off_category_id
      account = employee.account_id
      employee = employee.id
      amount = policy_addition
      options = { policy_credit_addition: true }

      CreateEmployeeBalance.new(category, employee, account, amount, options).call
    end
  end

  def counter_amount(policy, employee)
    last_balance = employee.last_balance_in_policy(policy.id).try(:balance)
    0 - last_balance.to_i
  end
end

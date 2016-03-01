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
      category, employee, account, amount, options =
        policy.time_off_category_id, employee.id, employee.account_id,
        counter_amount(policy, employee), { policy_credit_addition: true }

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

  def counter_amount(policy, employee)
    last_balance = employee.last_balance_in_policy(policy.id).try(:balance)
    0 - last_balance.to_i
  end
end

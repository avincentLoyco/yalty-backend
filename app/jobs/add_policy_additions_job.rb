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
      category_id = policy.time_off_category_id
      account_id = employee.account_id
      employee_id = employee.id
      options = { policy_credit_addition: true }

      next if addition_already_exist?(policy.id, employee) || not_active?(policy, employee)

      CreateEmployeeBalance.new(category_id, employee_id, account_id, nil, options).call
    end
  end

  def manage_balancer(policy)
    employees = Employee.where(id: policy.affected_employees_ids)
    policy_addition = policy.amount

    employees.each do |employee|
      category_id = policy.time_off_category_id
      account_id = employee.account_id
      employee_id = employee.id
      amount = policy_addition
      options = { policy_credit_addition: true, validity_date: policy_end_date(policy) }

      next if addition_already_exist?(policy.id, employee) || not_active?(policy, employee)

      CreateEmployeeBalance.new(category_id, employee_id, account_id, amount, options).call
    end
  end

  def addition_already_exist?(policy_id, employee_id)
    additions = Employee::Balance.employee_balances(employee_id, policy_id)
                                 .where('policy_credit_addition = true AND effective_at::date = ?',
                                   Time.zone.today)
                                 .count
    additions > 0
  end

  def policy_end_date(policy)
    return nil if policy.dates_blank?
    policy.end_date.to_s
  end

  def not_active?(policy, employee)
    policy != employee.active_policy_in_category(policy.time_off_category_id)
  end
end

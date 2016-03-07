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
      employee = employee.id
      options = { policy_credit_addition: true }

      next if addition_already_exist?(policy.id, employee)

      CreateEmployeeBalance.new(category, employee, account, nil, options).call
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
      options = { policy_credit_addition: true, validity_date: policy_end_date(policy) }

      next if addition_already_exist?(policy.id, employee)

      CreateEmployeeBalance.new(category, employee, account, amount, options).call
    end
  end

  def addition_already_exist?(policy_id, employee_id)
    additions = Employee::Balance.employee_balances(employee_id, policy_id)
                                 .where('policy_credit_addition = true AND effective_at::date = ?',
                                          Date.today
                                       ).count
    additions > 0
  end

  def policy_end_date(policy)
    return nil if policy.dates_blank?
    policy.end_date.to_s
  end
end

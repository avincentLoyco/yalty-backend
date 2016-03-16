module EmployeeBalanceUpdatePresencePerspective
  def find_and_update_balances(presence_policy)
    employees = Employee.where(id: presence_policy.affected_employees)

    employees.each do |employee|
      next if employee.time_offs.empty?

      categories = employee.time_offs.pluck(:time_off_category_id).uniq
      policies = TimeOffPolicy.where(time_off_category_id: categories).pluck(:id)

      policies.each do |policy_id|
        update_balances_in_affected_policy(policy_id, employee)
      end
    end
  end

  def update_balances_in_affected_policy(policy_id, employee)
    start_balance = employee.first_balance_in_policy(policy_id)

    balances_to_update = start_balance.all_later_ids

    Employee::Balance.where(id: balances_to_update).update_all(being_processed: true)
    UpdateBalanceJob.perform_later(start_balance.id, update_all: true)
  end
end

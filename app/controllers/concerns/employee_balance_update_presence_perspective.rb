module EmployeeBalanceUpdatePresencePerspective
  def find_and_update_balances(presence_policy)
    employees = Employee.where(id: presence_policy.affected_employees)

    employees.each do |employee|
      next if employee.time_offs.empty?

      categories = employee.time_offs.pluck(:time_off_category_id).uniq
      categories.each do |category_id|
        update_balances_in_affected_category(category_id, employee)
      end
    end
  end

  def update_balances(employees)
    employees.each do |employee|
      categories = employee.time_offs.pluck(:time_off_category_id).uniq
      categories.each do |category_id|
        update_balances_in_affected_category(category_id, employee)
      end
    end
  end

  def update_balances_in_affected_category(category_id, employee)
    start_balance = employee.first_balance_in_category(category_id)

    if start_balance.present?
      PrepareEmployeeBalancesToUpdate.new(start_balance).call
      UpdateBalanceJob.perform_later(start_balance.id, update_all: true)
    end
  end
end

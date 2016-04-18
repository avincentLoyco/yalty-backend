class UpdateAffectedEmployeeBalances
  attr_reader :presence_policy, :employees

  def initialize(presence_policy = nil, employees = [])
    @employees = employees
    @presence_policy = presence_policy
  end

  def call
    find_affected_employees unless employees.present? || presence_policy.blank?
    find_categories_and_update_balances
  end

  private

  def find_affected_employees
    @employees = Employee.where(id: presence_policy.affected_employees)
  end

  def find_categories_and_update_balances
    employees.each do |employee|
      next if employee.time_offs.empty?

      categories = employee.time_offs.pluck(:time_off_category_id).uniq
      categories.each do |category_id|
        update_balances_in_affected_category(category_id, employee)
      end
    end
  end

  def update_balances_in_affected_category(category_id, employee)
    start_balance = Employee::Balance.employee_balances(employee.id, category_id)
                                     .where('time_off_id IS NOT NULL')
                                     .order(:effective_at)
                                     .first

    if start_balance.present?
      PrepareEmployeeBalancesToUpdate.new(start_balance).call
      UpdateBalanceJob.perform_later(start_balance.id, update_all: true)
    end
  end
end

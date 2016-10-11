require 'active_support/concern'

module ValidateNoBalancesAfterJoinTableEffectiveAt
  extend ActiveSupport::Concern

  included do
    validate :balances_can_not_exist_after_effective_at, if: [:employee, :effective_at]
  end

  private

  def balances_can_not_exist_after_effective_at
    older = effective_at_was && effective_at_was < effective_at ? effective_at_was : effective_at
    return unless employee_balances_for_join_table(older).present?
    errors.add(:effective_at, 'Employee balance after effective at already exists')
  end

  def employee_balances_for_join_table(older_date)
    return find_balances_in_category(older_date) if self.class.eql?(EmployeeTimeOffPolicy)
    find_balances_without_time_offs(older_date)
  end

  def find_balances_in_category(older_date)
    assignation_balance_id = policy_assignation_balance(effective_at_was).try(:id)

    Employee::Balance
      .employee_balances(employee_id, time_off_policy.time_off_category_id)
      .where('effective_at >= ?', older_date)
      .where.not(id: assignation_balance_id)
  end

  def find_balances_without_time_offs(older_date)
    employee.employee_balances.where('effective_at >= ? AND time_off_id IS NOT NULL', older_date)
  end
end

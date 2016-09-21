class MigrateTimeOffBalances < ActiveRecord::Migration
  def change
    EmployeeTimeOffPolicy.transaction do
      EmployeeTimeOffPolicy.all.each do |etop|
        balance = Employee::Balance.find_or_create_by(
          employee: etop.employee,
          time_off_category: etop.time_off_category,
          effective_at: etop.effective_at
        )
        validity_date = RelatedPolicyPeriod.new(etop).validity_date_for(etop.effective_at)
        balance.update!(validity_date: validity_date)
        UpdateEmployeeBalance.new(balance, validity_date: validity_date)
      end
    end
    execute """
      UPDATE employee_balances SET effective_at = (
        SELECT time_offs.end_time FROM time_offs
        WHERE time_offs.id = employee_balances.time_off_id
      ) WHERE employee_balances.time_off_id IS NOT NULL;
    """
    Employee::Balance.transaction do
      Employee::Balance.where.not(time_off_id: nil).each do |balance|
        active_policy = balance.employee.active_policy_in_category_at_date(
          balance.time_off_category_id,
          balance.time_off.end_time
        )
        validity_date = RelatedPolicyPeriod.new(active_policy).validity_date_for_time_off(
          balance.time_off.end_time
        )
        UpdateEmployeeBalance.new(balance, validity_date: validity_date)
      end
    end
  end
end

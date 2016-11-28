class CreateEmployeeTimeOffPoliciesForOrphanBalances < ActiveRecord::Migration
  def up
    orphan_balances = Employee::Balance.joins('''
      LEFT JOIN (
        SELECT time_off_category_id, employee_id, min(effective_at) AS min_effective_at
        FROM employee_time_off_policies
        GROUP BY time_off_category_id, employee_id
      ) policies
      ON employee_balances.time_off_category_id = policies.time_off_category_id
      AND employee_balances.employee_id = policies.employee_id
    ''').where('''(
        policies.min_effective_at IS NOT NULL
        AND employee_balances.effective_at::date < policies.min_effective_at
      ) OR policies.min_effective_at IS NULL
    ''')

    data_for_etops = orphan_balances.reduce([]) do |acc, balance|
      acc.push(
        {
          employee_id: balance.employee_id,
          time_off_category_id: balance.time_off_category_id,
          effective_at: balance.employee.hired_date,
          time_off_policy_id: balance.time_off_category.time_off_policies.last.id
        }
      )
      acc
    end.uniq

    EmployeeTimeOffPolicy.create(data_for_etops).each do |etop|
      CreateEmployeeBalance.new(
        etop.time_off_category_id,
        etop.employee_id,
        etop.employee.account.id,
        effective_at: etop.effective_at + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
        validity_date: RelatedPolicyPeriod.new(etop).validity_date_for(etop.effective_at),
        manual_amount: 0,
        policy_credit_addition: false,
        skip_update: true
      ).call
    end
  end
end

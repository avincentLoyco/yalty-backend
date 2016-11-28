class ChangeEffectiveAtsOfBalances < ActiveRecord::Migration
  def up
    # Removals
    execute("""
      UPDATE employee_balances balances
      SET effective_at = balances.effective_at::date + interval '3 seconds'
      FROM employee_balances additions
      WHERE additions.balance_credit_removal_id = balances.id;
    """)

    # Start date / assignations
    execute("""
      UPDATE employee_balances
      SET effective_at = employee_balances.effective_at::date + interval '2 seconds',
	        validity_date = employee_balances.validity_date::date + interval '3 seconds'
      WHERE employee_balances.policy_credit_addition = true
      AND employee_balances.time_off_id IS NULL;
    """)

    # Assignations in other dates than start dates
    execute("""
      UPDATE employee_balances balances
      SET effective_at = balances.effective_at::date + interval '2 seconds',
          validity_date = balances.validity_date::date + interval '3 seconds'
      FROM employee_time_off_policies etops
      WHERE etops.effective_at::date = balances.effective_at::date
      AND etops.time_off_category_id = balances.time_off_category_id
      AND etops.employee_id = balances.employee_id
      AND balances.time_off_id IS NULL AND balances.policy_credit_addition = false;
    """)

    # Time offs
    execute("""
      UPDATE employee_balances
      SET validity_date = employee_balances.validity_date::date + interval '3 seconds'
      WHERE employee_balances.time_off_id IS NOT NULL;
    """)
  end
end

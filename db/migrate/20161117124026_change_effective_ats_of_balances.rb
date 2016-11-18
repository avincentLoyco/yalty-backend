class ChangeEffectiveAtsOfBalances < ActiveRecord::Migration
  def up
    execute("""
      UPDATE employee_balances balances
      SET effective_at = balances.effective_at + interval '3 seconds'
      FROM employee_balances additions
      WHERE additions.balance_credit_removal_id = balances.id;

      UPDATE employee_balances
      SET effective_at = employee_balances.effective_at + interval '2 seconds',
	        validity_date = employee_balances.validity_date + interval '3 seconds'
      WHERE employee_balances.policy_credit_addition = true
      AND employee_balances.time_off_id IS NULL;

      UPDATE employee_balances
      SET validity_date = employee_balances.validity_date + interval '3 seconds'
      WHERE employee_balances.time_off_id IS NOT NULL;
    """)
  end
end

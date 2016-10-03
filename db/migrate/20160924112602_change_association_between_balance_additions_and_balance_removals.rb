class ChangeAssociationBetweenBalanceAdditionsAndBalanceRemovals < ActiveRecord::Migration
  def change
    add_column :employee_balances, :balance_credit_removal_id, :uuid

    Employee::Balance.where.not(balance_credit_addition_id: nil).each do |removal_balance|
      Employee::Balance.find_by(id: removal_balance.balance_credit_addition_id)
                       .update!(balance_credit_removal_id: removal_balance.id)
    end

    remove_column :employee_balances, :balance_credit_addition_id
    remove_column :employee_balances, :policy_credit_removal
    add_index :employee_balances, :balance_credit_removal_id
  end
end

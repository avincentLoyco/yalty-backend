class AddStripeInfoToAccount < ActiveRecord::Migration
  def change
    add_column :accounts, :customer_id, :string
    add_column :accounts, :available_modules, :text, array: true
    add_column :accounts, :subscription_renewal_date, :date
    execute <<-SQL
      UPDATE accounts SET available_modules = '{}'::text[]
    SQL
    change_column_null :accounts, :available_modules, true, []
  end
end

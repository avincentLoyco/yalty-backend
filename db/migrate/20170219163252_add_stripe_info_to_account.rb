class AddStripeInfoToAccount < ActiveRecord::Migration
  def change
    add_column :accounts, :customer_id, :string
    add_column :accounts, :available_modules, :text, array: true, default: []
    add_column :accounts, :subscription_renewal_date, :date
  end
end

class AddAdditionalFieldsToInvoice < ActiveRecord::Migration
  def change
    add_column :invoices, :receipt_number, :integer
    add_column :invoices, :starting_balance, :integer
    add_column :invoices, :subtotal, :integer
    add_column :invoices, :tax, :integer
    add_column :invoices, :tax_percent, :decimal
    add_column :invoices, :total, :integer
  end
end

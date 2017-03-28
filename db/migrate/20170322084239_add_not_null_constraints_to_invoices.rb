class AddNotNullConstraintsToInvoices < ActiveRecord::Migration
  def change
    change_column_null(:invoices, :invoice_id, false)
    change_column_null(:invoices, :amount_due, false)
    change_column_null(:invoices, :status, false)
    change_column_null(:invoices, :date, false)
  end
end

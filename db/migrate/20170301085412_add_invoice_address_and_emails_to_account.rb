class AddInvoiceAddressAndEmailsToAccount < ActiveRecord::Migration
  def change
    add_column :accounts, :invoice_company_info, :hstore
    add_column :accounts, :invoice_emails, :text, array: true
    execute <<-SQL
      UPDATE accounts SET invoice_emails = '{}'::text[]
    SQL
    change_column_null :accounts, :invoice_emails, true, []
  end
end

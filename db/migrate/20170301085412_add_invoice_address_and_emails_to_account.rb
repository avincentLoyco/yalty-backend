class AddInvoiceAddressAndEmailsToAccount < ActiveRecord::Migration
  def change
    add_column :accounts, :invoice_company_info, :hstore
    add_column :accounts, :invoice_emails, :text, array: true, default: []
  end
end

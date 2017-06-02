class AddUniqueConstraintToInvoiceId < ActiveRecord::Migration
  def change
    add_index :invoices, :invoice_id, unique: true
  end
end

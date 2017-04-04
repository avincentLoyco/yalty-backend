class CreateInvoices < ActiveRecord::Migration
  def change
    create_table :invoices, id: :uuid do |t|
      t.string :invoice_id
      t.integer :amount_due
      t.string :status
      t.integer :attempts
      t.datetime :next_attempt
      t.datetime :date
      t.hstore :address
      t.json :lines
      t.belongs_to :account, type: :uuid, index: true
    end
  end
end

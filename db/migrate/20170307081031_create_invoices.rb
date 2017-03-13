class CreateInvoices < ActiveRecord::Migration
  def change
    create_table :invoices, id: :uuid do |t|
      t.integer :total_payed_amount, null: false
      t.string :status, null: false
      t.integer :attempts
      t.date :next_attempt
      t.date :date, null: false
      t.hstore :address
      t.json :invoice_items
      t.belongs_to :account, type: :uuid, index: true
    end
  end
end

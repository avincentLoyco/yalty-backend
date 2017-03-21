class CreateInvoices < ActiveRecord::Migration
  def change
    create_table :invoices, id: :uuid do |t|
      t.integer :amount_due, null: false
      t.string :status, null: false
      t.integer :attempts
      t.datetime :next_attempt
      t.datetime :date, null: false
      t.hstore :address
      t.json :lines
      t.belongs_to :account, type: :uuid, index: true
    end
  end
end

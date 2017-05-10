class AddPeriodStartAndEndToInvoice < ActiveRecord::Migration
  def change
    add_column :invoices, :period_start, :datetime
    add_column :invoices, :period_end, :datetime
  end
end

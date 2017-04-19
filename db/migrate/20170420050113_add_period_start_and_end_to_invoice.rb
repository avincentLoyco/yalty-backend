class AddPeriodStartAndEndToInvoice < ActiveRecord::Migration
  def change
    add_column :invoices, :period_start, :datetime
    add_column :invoices, :period_end, :datetime
    add_column :invoices, :charge_id, :string

    Account.all.each do |account|
      next if account.invoices.empty?

      stripe_invoices = Stripe::Invoice.list(limit: 100, customer: account.customer_id)

      account.invoices.each do |account_invoice|
        stripe_invoice = stripe_invoices.find { |i| i.id.eql?(account_invoice.invoice_id) }
        account_invoice.update!(
          period_start: Time.zone.at(stripe_invoice.period_start),
          period_end: Time.zone.at(stripe_invoice.period_end),
          charge_id: stripe_invoice.charge
        )
      end
    end
  end
end

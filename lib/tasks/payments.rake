namespace :payments do
  desc 'Create Stripe customer and subscription for accounts'
  task create_customers_for_existing_accounts: [:environment] do
    Account.where('customer_id IS NULL OR subscription_id IS NULL').find_each do |account|
      ::Payments::CreateOrUpdateCustomerWithSubscription.perform_later(account)
    end
  end

  desc 'Update Stripe customer and subscription for accounts'
  task update_customers_for_existing_accounts: [:environment] do
    Account.find_each do |account|
      ::Payments::CreateOrUpdateCustomerWithSubscription.perform_later(account)
    end
  end

  desc 'Updates available modules on Stripe for subscribed account'
  task update_available_modules: [:environment] do
    Account.where.not('available_modules::text = \'{"data":[]}\'::text').find_each do |account|
      ::Payments::UpdateAvailableModules.perform_later(account)
    end
  end

  desc 'Generate missing PDF for invoices'
  task generate_pdf_for_invoices: :environment do
    Invoice.includes(:generic_file).where(generic_files: { id: nil }).each do |invoice|
      Stripe::Invoice.list(customer: invoice.account.customer_id).auto_paging_each do |stripe_in|
        next unless stripe_in.id.eql?(invoice.invoice_id)
        invoice.update!(
          period_start: Time.zone.at(stripe_in.period_start),
          period_end: Time.zone.at(stripe_in.period_end),
          charge_id: stripe_in.charge
        )
        break
      end
      next unless invoice.status.eql?('success')
      ::Payments::CreateInvoicePdf.new(invoice).call
    end
  end

  def update_receipt_numbers
    "
      UPDATE invoices
      SET receipt_number = nextval('receipt_number_seq')
      WHERE
        invoices.status = 'success' AND
        invoices.receipt_number IS NULL
    "
  end
end

module Payments
  class StripeEventsHandler < ActiveJob::Base
    queue_as :billing

    attr_reader :account

    def perform(event_id)
      event = Stripe::Event.retrieve(event_id)

      @account = Account.find_by(customer_id: event.data.object.customer)

      case event.type
      when 'invoice.created' then
        account.transaction do
          create_invoice(event.data.object)
          clear_modules('canceled')
        end
      when 'invoice.payment_failed' then
        updated_invoice = update_invoice_status(event.data.object, 'failed')
        PaymentsMailer.payment_failed(updated_invoice.id).deliver_now
      when 'invoice.payment_succeeded' then
        updated_invoice = update_invoice_status(event.data.object, 'success')
        ::Payments::CreateInvoicePdf.new(updated_invoice).call
        PaymentsMailer.payment_succeeded(updated_invoice.id).deliver_now
      when 'customer.subscription.updated' then
        if event.data.object.status.eql?('canceled')
          account.transaction do
            clear_modules('all')
            recreate_subscription
          end

          PaymentsMailer.subscription_canceled(account.id).deliver_now
        end
      end
    end

    private

    def update_invoice_status(invoice, status)
      next_attempt = if invoice.next_payment_attempt.present?
                       Time.zone.at(invoice.next_payment_attempt).to_datetime
                     end

      account.invoices.find_by(invoice_id: invoice.id).tap do |updated_invoice|
        updated_invoice.update!(
          status: status,
          attempts: invoice.attempt_count,
          next_attempt: next_attempt
        )
      end
    end

    def create_invoice(invoice)
      invoice_lines = []
      invoice.lines.auto_paging_each do |line|
        next if line.plan.id.eql?('free-plan') || canceled_modules.include?(line.plan.id)
        invoice_lines.push(line)
      end

      return if invoice_lines.empty? ||
          Stripe::Subscription.retrieve(invoice.subscription).status == 'trialing'

      account.invoices.create(
        invoice_id: invoice.id,
        amount_due: invoice.amount_due,
        attempts: invoice.attempt_count,
        date: Time.zone.at(invoice.date).to_datetime,
        status: 'pending',
        starting_balance: invoice.starting_balance,
        subtotal: invoice.subtotal,
        tax: invoice.tax,
        tax_percent: invoice.tax_percent,
        total: invoice.total,
        address: account.invoice_company_info,
        period_start: Time.zone.at(invoice.period_start),
        period_end: Time.zone.at(invoice.period_end),
        lines: InvoiceLines.new(data: invoice_lines.map { |line| build_invoice_line(line) })
      )
    end

    def build_invoice_line(line_item)
      Payments::InvoiceLine.new(
        id: line_item.id,
        amount: line_item.amount,
        currency: 'chf',
        period_start: line_item.period.start,
        period_end: line_item.period.end,
        proration: line_item.proration,
        quantity: line_item.quantity,
        subscription: line_item.subscription,
        subscription_item: line_item.subscription_item,
        type: line_item.type,
        plan: build_plan(line_item.plan)
      )
    end

    def build_plan(plan)
      Payments::Plan.new(
        id: plan.id,
        name: plan.name,
        amount: plan.amount,
        currency: plan.currency,
        interval: plan.interval,
        interval_count: plan.interval_count
      )
    end

    def recreate_subscription
      subscription = Stripe::Subscription.create(
        customer: account.customer_id,
        plan: 'free-plan',
        tax_percent: Invoice::TAX_PERCENT,
        quantity: account.employees.active_at_date(Time.zone.tomorrow).count
      )

      account.update!(subscription_id: subscription.id)
    end

    def clear_modules(scope)
      case scope
      when 'all' then account.available_modules.delete_all
      when 'canceled' then account.available_modules.clean
      end

      account.save!
    end

    def canceled_modules
      @canceled_modules ||= account.available_modules.canceled
    end
  end
end

module Payments
  class StripeEventsHandler < ActiveJob::Base
    queue_as :billing

    attr_reader :account

    def perform(event_id)
      event = Stripe::Event.retrieve(event_id)

      @account = Account.find_by(customer_id: event.data.object.customer)

      case event.type
      when 'invoice.created' then
        create_invoice(event.data.object)
        update_avaiable_modules(event.data.object)
      when 'invoice.payment_failed' then
        update_invoice_status(event.data.object, 'failed')
      when 'invoice.payment_succeeded' then
        update_invoice_status(event.data.object, 'success')
        # TODO: Add pdf generation here

      when 'customer.subscription.updated' then
        update_avaiable_modules(event.data.object)
      end
    end

    private

    def update_invoice_status(invoice, status)
      next_attempt = if invoice.next_payment_attempt.present?
        Time.zone.at(invoice.next_payment_attempt).to_datetime
      end

      account.invoices.where(invoice_id: invoice.id).update_all(
        status: status,
        attempts: invoice.attempt_count,
        next_attempt: next_attempt
      )
    end

    def create_invoice(invoice)
      invoice_lines =
        invoice.lines.data.select { |line| !line.plan.id.eql?('free-plan') }
               .map { |line| build_invoice_line(line) }
      return if invoice_lines.empty?

      account.invoices.create(
        invoice_id: invoice.id,
        amount_due: invoice.amount_due,
        attempts: invoice.attempt_count,
        date: Time.zone.at(invoice.date).to_datetime,
        status: 'pending',
        receipt_number: invoice.receipt_number,
        starting_balance: invoice.starting_balance,
        subtotal: invoice.subtotal,
        tax: invoice.tax,
        tax_percent: invoice.tax_percent,
        total: invoice.total,
        address: account.invoice_company_info,
        lines: InvoiceLines.new(data: invoice_lines)
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

    def update_avaiable_modules(object)
      plans =
        if object&.status.eql?('canceled')
          []
        elsif object.object.eql?('subscription')
          stripe_sub = Stripe::Subscription.retrieve(object.id)
          stripe_sub.items.map { |si| si.plan.id unless si.plan.id.eql?('free-plan') }.compact
        end

      account.update(available_modules: plans) unless plans.nil?
    end
  end
end

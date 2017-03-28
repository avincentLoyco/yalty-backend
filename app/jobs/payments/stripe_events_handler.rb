module Payments
  class StripeEventsHandler < ActiveJob::Base
    queue_as :billing

    def perform(event)
      case event.type
      when 'invoice.created' then
        invoice_lines = event.data.object.lines.data.map { |line| build_invoice_line(line) }
        create_invoice(event.data.object, InvoiceLines.new(data: invoice_lines))
      when 'invoice.payment_failed' then
        update_invoice_status(event.data.object, 'failed')
      when 'invoice.payment_succeeded' then
        update_invoice_status(event.data.object, 'success')
        # TODO add pdf generation here

      when 'customer.subscription.updated' then
        Account.current.update(available_modules: []) if event.data.object.status == 'canceled'
      end
    end

    private

    def update_invoice_status(invoice, status)
      Account.current.invoices.where(invoice_id: invoice.id).update_all(
        status: status,
        attempts: invoice.attempt_count,
        next_attempt: Time.zone.at(invoice.next_payment_attempt).to_datetime
      )
    end

    def create_invoice(invoice, invoice_lines)
      Account.current.invoices.create(
        invoice_id: invoice.id,
        amount_due: invoice.amount_due,
        attempts: invoice.attempt_count,
        next_attempt: Time.zone.at(invoice.next_payment_attempt).to_datetime,
        date: Time.zone.at(invoice.date).to_datetime,
        status: 'pending',
        address: Account.current.invoice_company_info,
        lines: invoice_lines
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
  end
end

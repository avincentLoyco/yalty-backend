module Payments
  class StripeEventsHandler < ActiveJob::Base
    queue_as :billing

    def perform(event)
      case event.type
      when 'invoice.created' then # create Invoice object with pending status
      when 'invoice.payment_failed' then # set invoice object state to failed
      when 'invoice.payment_succeeded' then # generate PDF and set status to success
      when 'customer.subscription.update' then # where status changed from ACTIVE to CANCELED: we remove all avaialable_modules from account
      end
    end
  end
end

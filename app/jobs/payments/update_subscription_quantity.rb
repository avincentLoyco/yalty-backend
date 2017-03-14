module Payments
  class UpdateSubscriptionQuantity < ActiveJob::Base
    queue_as :billing

    rescue_from(
      Stripe::InvalidRequestError,
      Stripe::AuthenticationError,
      Stripe::PermissionError,
      Stripe::RateLimitError,
      Stripe::APIError
    ) do
      retry_job(wait: 10.seconds)
    end

    def initialize
      super
      @tomorrow = Time.zone.tomorrow
    end

    def perform
      accounts_with_quantity_to_update.each do |account|
        update_subscription_items(account)
      end
    end

    private

    def accounts_with_quantity_to_update
      (events_tomorrow | events_recently_updated).reduce([]) do |accounts, event|
        accounts.push(event.account) if !accounts.include?(event.account)
        accounts
      end
    end

    def events_tomorrow
      hired_or_contract_end_events.where('effective_at = ?::date', @tomorrow)
    end

    def events_recently_updated
      hired_or_contract_end_events.where(
        'updated_at BETWEEN ? AND ?',
        Time.zone.yesterday.beginning_of_day,
        Time.zone.today.beginning_of_day
      )
    end

    def hired_or_contract_end_events
      @hired_or_contract_end_events ||=
        Employee::Event.where("(event_type = 'hired' OR event_type = 'contract_end')")
    end

    def update_subscription_items(account)
      employees_count = account.employees.active_at_date(@tomorrow).count
      proration_date = proration_date_for(account)

      Stripe::SubscriptionItem.list(subscription: account.subscription_id).each do |sub_item|
        next if sub_item.quantity.eql?(employees_count)
        sub_item.quantity = employees_count
        sub_item.prorate = true
        sub_item.proration_date = proration_date
        sub_item.save
      end
    end

    def proration_date_for(account)
      invoice_date = Time.zone.at(Stripe::Invoice.upcoming(customer: account.customer_id).date)
      DateTime.new(
        @tomorrow.year,
        @tomorrow.month,
        @tomorrow.day,
        invoice_date.hour,
        invoice_date.min,
        invoice_date.sec,
        invoice_date.zone
      ).to_i
    end
  end
end

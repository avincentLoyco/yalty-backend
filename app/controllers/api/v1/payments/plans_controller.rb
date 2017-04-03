module API
  module V1
    module Payments
      class PlansController < ApplicationController
        include PlansSchemas
        include PaymentsHelper

        def create
          verified_dry_params(dry_validation_schema) do |attributes|
            plan = Account.current.with_lock do
              adjust_available_modules(:push, attributes[:id])
              create_plan(attributes[:id])
            end
            ::Payments::UpdateSubscriptionQuantity.perform_later(Account.current)
            render json: resource_representer.new(plan).complete
          end
        end

        def destroy
          verified_dry_params(dry_validation_schema) do |attributes|
            plan = Account.current.with_lock do
              adjust_available_modules(:delete, attributes[:id])
              delete_subscription_item(attributes[:id])
            end
            render json: resource_representer.new(plan).complete
          end
        end

        private

        def create_plan(plan_id)
          plan = Stripe::SubscriptionItem.create(
            subscription: Account.current.subscription_id,
            plan: plan_id,
            quantity: Account.current.employees.active_at_date.count,
            prorate: Account.current.available_modules.size > 1,
            proration_date: proration_date
          ).plan
          plan.active = true
          plan
        end

        def delete_subscription_item(plan_id)
          subscription_item = find_subscription_item(plan_id)
          plan = subscription_item.plan
          subscription_item.delete(proration_date: proration_date)
          plan.active = false
          plan
        end

        def find_subscription_item(plan_id)
          Stripe::SubscriptionItem
            .list(subscription: Account.current.subscription_id)
            .find do |subscription_item|
              subscription_item.plan.id.eql?(plan_id)
            end
        end

        def adjust_available_modules(method, plan_id)
          Account.current.available_modules.send(method, plan_id)
          Account.current.save
        end

        def resource_representer
          ::Api::V1::Payments::PlanRepresenter
        end

        def proration_date
          today = Time.zone.today
          invoice_date =
            Time.zone.at(Stripe::Invoice.upcoming(customer: Account.current.customer_id).date)
          DateTime.new(today.year, today.month, today.day, invoice_date.hour, invoice_date.min,
            invoice_date.sec, invoice_date.zone).to_i
        end
      end
    end
  end
end

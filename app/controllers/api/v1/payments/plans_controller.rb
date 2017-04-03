module API
  module V1
    module Payments
      class PlansController < ApplicationController
        include PlansSchemas
        include PaymentsHelper

        def create
          verified_dry_params(dry_validation_schema) do |attributes|
            plan = Account.current.with_lock do
              add_to_available_modules(attributes[:id])
              create_plan(attributes[:id])
            end
            ::Payments::UpdateSubscriptionQuantity.perform_later(Account.current)
            render json: resource_representer.new(plan).complete
          end
        end

        def destroy
          verified_dry_params(dry_validation_schema) do |attributes|
            plan = delete_subscription_item(attributes[:id])
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
            proration_date: proration_date(Time.zone.today)
          ).plan
          plan.active = true
          plan
        end

        def delete_subscription_item(plan_id)
          subscription_item = find_subscription_item(plan_id)
          plan = subscription_item.plan
          subscription_item.delete(proration_date: proration_date(current_period_end))
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

        def add_to_available_modules(plan_id)
          Account.current.available_modules.push(plan_id)
          Account.current.save
        end

        def resource_representer
          ::Api::V1::Payments::PlanRepresenter
        end

        def proration_date(date)
          DateTime.new(date.year, date.month, date.day, current_period_end.hour,
            current_period_end.min, current_period_end.sec, current_period_end.zone).to_i
        end

        def current_period_end
          @current_period_end ||= Time.zone.at(
            Stripe::Subscription.retrieve(Account.current.subscription_id).current_period_end
          )
        end
      end
    end
  end
end

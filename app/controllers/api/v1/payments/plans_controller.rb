module API
  module V1
    module Payments
      class PlansController < ApplicationController
        include PlansSchemas
        include PaymentsHelper

        def create
          verified_dry_params(dry_validation_schema) do |attributes|
            plan = Account.current.with_lock { create_plan(attributes[:id]) }
            ::Payments::UpdateSubscriptionQuantity.perform_later(Account.current)
            render json: resource_representer.new(plan).complete
          end
        end

        def destroy
          verified_dry_params(dry_validation_schema) do |attributes|
            Account.current.with_lock { cancel_plan_module(attributes[:id]) }
            render_no_content
          end
        end

        private

        def create_plan(plan_id)
          if Account.current.available_modules.include?(plan_id)
            Account.current.available_modules.reactivate(plan_id)
            Account.current.save!
            find_plan(plan_id, true)
          else
            Account.current.available_modules.add(id: plan_id)
            Account.current.save!
            subscribe_on_stripe(plan_id)
          end
        end

        def subscribe_on_stripe(plan_id)
          # TODO: Temporary trial
          subscription.trial_end = 10.days.from_now.to_i
          subscription.save
          plan = Stripe::SubscriptionItem.create(plan_creation_params(plan_id)).plan
          plan.active = true
          plan
        end

        def plan_creation_params(plan_id)
          prorate = Account.current.available_modules.size > 1
          creation_params = {
            subscription: Account.current.subscription_id,
            plan: plan_id,
            quantity: Account.current.employees.chargeable_at_date.count,
            prorate: prorate
          }
          return creation_params unless prorate
          creation_params.merge(proration_date: proration_date(Time.zone.today))
        end

        def cancel_plan_module(plan_id)
          if subscription.status.eql?('trialing')
            Account.current.available_modules.delete(plan_id)
            Account.current.save!
            find_subscription_item(plan_id).delete
          else
            Account.current.available_modules.cancel(plan_id)
            Account.current.save!
          end
        end

        def find_plan(plan_id, active)
          plan = find_subscription_item(plan_id).plan
          plan.active = active
          plan ||
            raise(StripeError.new(type: 'plan', field: 'id', message: "No such plan: #{plan_id}"),
              'No such plan')
        end

        def find_subscription_item(plan_id)
          Stripe::SubscriptionItem.list(subscription: subscription.id)
                                  .find { |si| si.plan.id.eql?(plan_id) }
        end

        def resource_representer
          ::Api::V1::Payments::PlanRepresenter
        end

        def proration_date(date)
          DateTime.new(date.year, date.month, date.day, current_period_end.hour,
            current_period_end.min, current_period_end.sec, current_period_end.zone).to_i
        end

        def current_period_end
          @current_period_end ||= Time.zone.at(subscription.current_period_end)
        end

        def subscription
          @subscription ||= Stripe::Subscription.retrieve(Account.current.subscription_id)
        end

        def stripe_error(exception)
          error = StripeError.new(type: 'plan', field: 'id', message: exception.message)
          render json: ::Api::V1::StripeErrorRepresenter.new(error).complete, status: 502
        end
      end
    end
  end
end

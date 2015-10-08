module API
  module V1
    class HolidayPoliciesController < ApplicationController
      def show
        rules = gate_member_rule
        verified_params(rules) do |attributes|
          render_json(holiday_policy)
        end
      end

      def index
        response = holiday_policies.map do |holiday_policy|
          HolidayPolicyRepresenter.new(holiday_policy).complete
        end
        render json: response
      end

      def create
        rules = Gate.rules do
          required :name, :String
          optional :region, :String
          optional :country, :String
          optional :employees, :Array
          optional :working_places, :Array
          optional :holidays, :Array
        end

        verified_params(rules) do |attributes|
          holiday_policy = Account.current.holiday_policies.create(attributes)
          if holiday_policy.save
            render_json(holiday_policy)
          else
            render_error_json(holiday_policy)
          end
        end
      end

      def update
        rules = Gate.rules do
          required :id, :String
          required :name, :String
          optional :region, :String
          optional :country, :String
          optional :employees, :Array
          optional :working_places, :Array
          optional :holidays, :Array
        end

        verified_params(rules) do |attributes|
          if holiday_policy.update(attributes)
            head 204
          else
            render_error_json(holiday_policy)
          end
        end
      end

      def destroy
        rules = gate_member_rule
        verified_params(rules) do |attributes|
          holiday_policy.destroy!
          head 204
        end
      end

      private

      def holiday_policy
        @holiday_policy ||= Account.current.holiday_policies.find(params[:id])
      end

      def holiday_policies
        @holiday_policies = Account.current.holiday_policies
      end

      def render_json(holiday_policy)
        render json: HolidayPolicyRepresenter.new(holiday_policy).complete
      end
    end
  end
end

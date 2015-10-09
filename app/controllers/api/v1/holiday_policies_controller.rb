module API
  module V1
    class HolidayPoliciesController < ApplicationController
      include HolidayPolicyRules

      def show
        render_json(holiday_policy)
      end

      def index
        response = holiday_policies.map do |holiday_policy|
          HolidayPolicyRepresenter
            .new(holiday_policy)
            .complete
        end

        render json: response
      end

      def create
        verified_params(gate_rules) do |attributes|
          holiday_policy = Account.current.holiday_policies.new(attributes)
          if holiday_policy.save
            render_json(holiday_policy)
          else
            render_error_json(holiday_policy)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          if holiday_policy.update(attributes)
            head 204
          else
            render_error_json(holiday_policy)
          end
        end
      end

      def destroy
        holiday_policy.destroy!
        head 204
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

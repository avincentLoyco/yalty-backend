module API
  module V1
    class HolidaysController < ApplicationController
      include HolidayRules

      def show
        render_json(holiday)
      end

      def index
        response =  holidays.map do |holiday|
          HolidayRepresenter.new(holiday).complete
        end

        render json: response
      end

      def create
        verified_params(gate_rules) do |attributes|
          holiday = holiday_policy.holidays.new(attributes)
          if holiday.save
            render_json(holiday)
          else
            resource_invalid_error(holiday)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          if holiday.update(attributes)
            head 204
          else
            resource_invalid_error(holiday)
          end
        end
      end

      def destroy
        holiday.destroy!
        head 204
      end

      private

      def holiday
        @holiday ||= holiday_policy.holidays.find(params[:id])
      end

      def holidays
        @holidays ||= holiday_policy.holidays
      end

      def holiday_policy
        @holiday_policy ||= Account.current.holiday_policies.find(params[:holiday_policy_id])
      end

      def render_json(holiday)
        render json: HolidayRepresenter.new(holiday).complete
      end
    end
  end
end

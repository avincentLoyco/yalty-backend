module API
  module V1
    class HolidaysController < ApplicationController
      load_and_authorize_resource except: :create
      include HolidayRules

      def show
        render_resource(resource)
      end

      def index
        render_resource(holiday_policy.holidays)
      end

      def create
        verified_params(gate_rules) do |attributes|
          resource = holiday_policy.custom_holidays.new(holiday_attributes(attributes))
          authorize! :create, resource

          if resource.save
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          if resource.update(attributes)
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      def destroy
        resource.destroy!
        render_no_content
      end

      private

      def holiday_attributes(attributes)
        attributes.tap { |attr| attr.delete(:holiday_policy) }
      end

      def resource
        @resource ||= Account.current.custom_holidays.find(params[:id])
      end

      def resources
        @resources ||= holiday_policy.custom_holidays
      end

      def holiday_policy
        @holiday_policy ||= Account.current.holiday_policies.find(holiday_policy_params)
      end

      def resource_representer
        ::Api::V1::HolidayRepresenter
      end

      def holiday_policy_params
        params[:holiday_policy_id] ? params[:holiday_policy_id] : params[:holiday_policy][:id]
      end
    end
  end
end

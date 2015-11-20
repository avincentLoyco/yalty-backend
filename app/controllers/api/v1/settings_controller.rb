module API
  module V1
    class SettingsController < API::ApplicationController
      include SettingsRules
      before_action :subdomain_access!, only: :show
      skip_action_callback :authenticate!, only: :show

      def show
        if Account::User.current.present?
          render_resource(resource)
        else
          render json: resource_representer.new(resource).public_data
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          if attributes.key?(:holiday_policy)
            holiday_policy = attributes.delete(:holiday_policy)
            assign_holiday_policy(holiday_policy)
          end

          if resource.update(attributes)
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      private

      def assign_holiday_policy(holiday_policy)
        if holiday_policy.present?
          holiday_policy_id = holiday_policy.try(:[], :id)
          holiday_policy = resource.holiday_policies.find(holiday_policy_id)
          resource.holiday_policy = holiday_policy
        else
          resource.holiday_policy = nil
        end
      end

      def resource
        Account.current
      end

      def resource_representer
        ::Api::V1::SettingsRepresenter
      end
    end
  end
end

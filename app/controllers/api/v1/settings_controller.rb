module API
  module V1
    class SettingsController < API::ApplicationController
      include SettingsRules

      def show
        render_json
      end

      def update
        verified_params(gate_rules) do |attr|
          if attr.has_key?(:holiday_policy)
            holiday_policy = attr.delete(:holiday_policy)
            assign_holiday_policy(holiday_policy)
          end

          if settings.update(attr)
            render_no_content
          else
            resource_invalid_error(settings)
          end
        end
      end

      private

      def assign_holiday_policy(holiday_policy)
        if holiday_policy.present?
          holiday_policy_id = holiday_policy.try(:[], :id)
          holiday_policy = settings.holiday_policies.find(holiday_policy_id)
          settings.holiday_policy = holiday_policy
        else
          settings.holiday_policy = nil
        end
      end

      def render_json
        render json: SettingsRepresenter.new(settings).complete
      end

      def settings
        Account.current
      end

    end
  end
end

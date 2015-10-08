module API
  module V1
    class SettingsController < API::ApplicationController

      def show
        render json: SettingsRepresenter.new(settings).complete
      end

      def update
        gate = Gate.rules do
          optional :subdomain
          optional :company_name
          optional :timezone
          optional :default_locale
          optional :holiday_policy, allow_nil: true do
            required :id
          end
        end
        result = gate.verify(params)
        if result.valid? && result.attributes.present?
          if result.attributes.has_key?(:holiday_policy)
            holiday_policy = result.attributes.delete(:holiday_policy)
            assign_holiday_policy(holiday_policy)
          end

          if settings.update(result.attributes)
            render status: :no_content, nothing: true
          else
            render json: ErrorsRepresenter.new(settings.errors.messages, 'settings').resource,
              status: 422
          end
        else
          render json: ErrorsRepresenter.new(result.errors, 'settings').resource,
            status: 422
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

      def settings
        Account.current
      end

    end
  end
end

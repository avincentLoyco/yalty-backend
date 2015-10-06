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
          optional :holiday_policy do
            required :id
          end
        end
        result = gate.verify(params)

        if result.valid?
          holiday_policy_id = result.attributes.delete(:holiday_policy)[:id]
          assign_holiday_policy(holiday_policy_id)
          settings.update(result.attributes)
          if settings.save
            render status: :no_content, nothing: true
          else
            render json: ResourceErrorsRepresenter.new(settings.errors.messages, 'settings').basic, status: 422
          end
        else
          render json: {status: "error", message: "Invalid params" }, status: 422
        end
      end

      private

      def assign_holiday_policy(holiday_policy_id)
        holiday_policy = settings.holiday_policies.find(holiday_policy_id)
        settings.holiday_policy = holiday_policy
      end

      def settings
        Account.current
      end

    end
  end
end

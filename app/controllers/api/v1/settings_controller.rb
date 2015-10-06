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
          assign_holiday_policy!(holiday_policy_id)
          settings.update!(result.attributes)
          render status: :no_content, nothing: true
        else
        end
      end

      private

      def assign_holiday_policy!(holiday_policy_id)
        holiday_policy = settings.holiday_policies.find(holiday_policy_id)
        settings.holiday_policy = holiday_policy
        settings.save!
      end

      def settings
        Account.current
      end

    end
  end
end

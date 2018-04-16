module Events
  module WorkContract
    class Create < Default::Create
      include API::V1::Exceptions

      config_accessor :etop_creator do
        CreateEtopForEvent
      end

      def call
        ActiveRecord::Base.transaction do
          event.tap do
            handle_hired_or_work_contract_event
          end
        end
      end

      private

      def handle_hired_or_work_contract_event
        ActiveRecord::Base.transaction do
          validate_time_off_policy_days_presence
          validate_presence_policy_presence

          EmployeePolicy::Presence::Create.call(presence_policy_params)
          validate_matching_occupation_rate

          etop_creator.new(event.id, time_off_policy_amount).call
        end
      end

      def validate_time_off_policy_days_presence
        return unless time_off_policy_amount.nil?
        raise InvalidResourcesError.new(event, ["Time Off Policy amount not present"])
      end

      def validate_presence_policy_presence
        return unless params[:presence_policy_id].nil?
        raise InvalidResourcesError.new(event, ["Presence Policy days not present"])
      end

      def validate_matching_occupation_rate
        return if presence_policy_occupation_rate.eql?(event_occupation_rate)
        raise InvalidResourcesError.new(event, ["Occupation Rate does not match Presence Policy"])
      end

      def time_off_policy_amount
        return if params[:time_off_policy_amount].nil?
        default_full_time_policy = Account.current.presence_policies.full_time
        params[:time_off_policy_amount] * default_full_time_policy.standard_day_duration
      end

      def presence_policy_params
        {
          event_id: event.id,
          presence_policy_id: params[:presence_policy_id],
        }
      end

      def presence_policy_occupation_rate
        event.employee_presence_policy.presence_policy.occupation_rate
      end

      def event_occupation_rate
        event.attribute_value("occupation_rate").to_f
      end
    end
  end
end

module Events
  module WorkContract
    class Update < Default::Update
      include API::V1::Exceptions

      config_accessor :etop_updater do
        UpdateEtopForEvent
      end

      class << self
        def call(event, params)
          new(event, params).call
        end
      end

      pattr_initialize :event, :params do
        @old_effective_at = event.effective_at
      end

      def call
        update_event.tap do
          handle_hired_or_work_contract_event
        end
      end

      private

      attr_reader :old_effective_at

      def handle_hired_or_work_contract_event
        ActiveRecord::Base.transaction do
          validate_time_off_policy_days_presence
          validate_presence_policy_presence

          if params[:presence_policy_id].eql?(event.employee_presence_policy&.presence_policy&.id)
            EmployeePolicy::Presence::Update.call(update_presence_policy_params)
          else
            EmployeePolicy::Presence::Destroy.call(event.employee_presence_policy)
            EmployeePolicy::Presence::Create.call(create_presence_policy_params)
          end

          validate_matching_occupation_rate

          etop_updater.new(event.id, params[:time_off_policy_amount], old_effective_at).call
        end
      end

      def validate_time_off_policy_days_presence
        return unless params[:time_off_policy_amount].nil?
        raise InvalidResourcesError.new(event, ["Time Off Policy amount not present"])
      end

      def validate_presence_policy_presence
        return unless params[:presence_policy_id].nil?
        raise InvalidResourcesError.new(event, ["Presence Policy days not present"])
      end

      def update_presence_policy_params
        {
          id: event.employee_presence_policy.id,
          effective_at: params[:effective_at]
        }
      end

      def create_presence_policy_params
        {
          event_id: event.id,
          presence_policy_id: params[:presence_policy_id]
        }
      end

      def validate_matching_occupation_rate
        return if presence_policy_occupation_rate.eql?(event_occupation_rate)
        raise InvalidResourcesError.new(event, ["Occupation Rate does not match Presence Policy"])
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

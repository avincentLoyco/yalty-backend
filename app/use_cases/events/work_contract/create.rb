module Events
  module WorkContract
    class Create < Default::Create
      include EndOfContractHandler # eoc_event, destroy_eoc_balance, recreate_eoc_balance
      include AppDependencies[
        create_etop_for_event_service: "services.event.create_etop_for_event",
        create_employee_presence_policy_service: "services.employee_policy.presence.create",
        assign_employee_to_all_tops: "use_cases.employees.assign_employee_to_all_tops",
        account_model: "models.account",
        invalid_resources_error: "errors.invalid_resources_error",
        find_and_destroy_eoc_balance: "use_cases.balances.end_of_contract.find_and_destroy",
        create_eoc_balance: "use_cases.balances.end_of_contract.create",
        find_first_eoc_event_after: "use_cases.events.contract_end.find_first_after_date",
      ]

      def call(params)
        ActiveRecord::Base.transaction do
          super.tap do |created_event|
            destroy_eoc_balance if eoc_event
            handle_hired_or_work_contract_event
            # NOTE: Assignations to time off policies are created after the hire event is created -
            # FE is calling API endpoints for creating assignations to all of the default
            # time off policies (from default time off categories like maternity, sickness etc.)
            # Assignations are therefore created two times. To fix that and move the whole logic to
            # BE, we need to do proper refactor and it was agreed to not to do that in the scope
            # of this task (task for refactor - YA-2091). After commenting out the line below
            # - newly hired employee won't be assigned to time off policies from
            # custom time off categories. The proper fix will be introduced in the mentioned task.

            # assign_employee_to_all_tops.call(created_event.employee)

            recreate_eoc_balance if eoc_event
          end
        end
      end

      private

      def handle_hired_or_work_contract_event
        validate_time_off_policy_days_presence
        validate_presence_policy_presence

        create_employee_presence_policy_service.call(presence_policy_params)
        validate_matching_occupation_rate

        create_etop_for_event_service.new(event.id, time_off_policy_amount).call
      end

      # TODO: extract all validations to a separate file
      def validate_time_off_policy_days_presence
        return unless time_off_policy_amount.nil?
        raise invalid_resources_error.new(event, ["Time Off Policy amount not present"])
      end

      def validate_presence_policy_presence
        return unless params[:presence_policy_id].nil?
        raise invalid_resources_error.new(event, ["Presence Policy days not present"])
      end

      def validate_matching_occupation_rate
        return if presence_policy_occupation_rate.eql?(event_occupation_rate)
        raise invalid_resources_error.new(event, ["Occupation Rate does not match Presence Policy"])
      end

      def presence_policy_occupation_rate
        event.employee_presence_policy.presence_policy.occupation_rate
      end

      def time_off_policy_amount
        return if params[:time_off_policy_amount].nil?
        params[:time_off_policy_amount] * account_model.current.standard_day_duration
      end

      def presence_policy_params
        {
          event_id: event.id,
          presence_policy_id: params[:presence_policy_id],
        }
      end

      def event_occupation_rate
        event.attribute_value("occupation_rate").to_f
      end
    end
  end
end

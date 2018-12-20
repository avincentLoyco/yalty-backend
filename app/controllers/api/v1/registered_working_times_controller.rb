module API
  module V1
    class RegisteredWorkingTimesController < ApplicationController
      include RegisteredWorkingTimeSchemas
      include AppDependencies[
        create_or_update_registered_working_time:
          "use_cases.registered_working_times.create_or_update",
        account_model: "models.account",
        registered_working_time_model: "models.registered_working_time",
      ]

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :create, resource

          create_or_update_registered_working_time.call(
            registered_working_time: resource,
            employee: employee,
            params: attributes,
          )
          render_no_content
        end
      end

      private

      def employee
        account_model.current.employees.find(params[:employee_id])
      end

      def resource
        @resource ||=
          registered_working_time_model.find_or_initialize_by(
            employee: employee, date: params[:date]
          )
      end
    end
  end
end

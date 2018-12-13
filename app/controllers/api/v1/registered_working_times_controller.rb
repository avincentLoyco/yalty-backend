module API
  module V1
    class RegisteredWorkingTimesController < ApplicationController
      include RegisteredWorkingTimeSchemas
      include AppDependencies[
        create_or_update_registered_working_time: "use_cases.registered_working_times.create_or_update",
      ]

      def create
        authorize! :create, RegisteredWorkingTime

        verified_dry_params(dry_validation_schema) do |attributes|
          create_or_update_registered_working_time.call(
            employee: employee,
            date: attributes[:date],
            params: attributes,
          )
          render_no_content
        end
      end

      private

      def employee
        Account.current.employees.find(params[:employee_id])
      end
    end
  end
end

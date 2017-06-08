module API
  module V1
    class RegisteredWorkingTimesController < ApplicationController
      include RegisteredWorkingTimeSchemas

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :create, resource
          resource.update!(
            comment: attributes[:comment],
            time_entries: filtered_attributes(attributes)
          )
          render_no_content
        end
      end

      private

      def filtered_attributes(attributes)
        return [] if attributes[:time_entries].nil?
        attributes[:time_entries].map do |entry|
          next unless entry.is_a?(Hash)
          entry.except('type')
        end
      end

      def employee
        Account.current.employees.find(params[:employee_id])
      end

      def resource
        @resource ||=
          RegisteredWorkingTime.find_or_initialize_by(
            employee: employee, date: parse_or_raise_error
          )
      end

      def parse_or_raise_error
        Date.parse(params[:date])
      rescue
        raise(
          CustomError,
          type: controller_name,
          field: 'date',
          messages: ['Date must be valid date'],
          codes: ['registered_working_time.must_be_valid_date']
        )
      end
    end
  end
end

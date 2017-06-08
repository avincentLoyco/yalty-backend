module API
  module V1
    class SchedulesController < ApplicationController
      include SchedulesSchemas

      def schedule_for_employee
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :schedule_for_employee, employee
          from, to = parsed_attributes(attributes)
          schedule = ScheduleForEmployee.new(employee, from, to).call
          render json: schedule
        end
      end

      private

      def employee
        @employee ||= Account.current.employees.find(params[:employee_id])
      end

      def parsed_attributes(attributes)
        [parse_or_raise_error(attributes[:from]), parse_or_raise_error(attributes[:to])]
      end

      def parse_or_raise_error(string)
        Date.parse(string)
      rescue
        raise(CustomError.new(
          type: 'schedule',
          field: 'date',
          messages: ['From and to params must be in date format'],
          codes: ['schedule.from_and_to_must_be_in_date_format']
        ))
      end
    end
  end
end

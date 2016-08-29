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
        raise InvalidParamTypeError.new('Schedule', 'From and to params must be in date format')
      end
    end
  end
end

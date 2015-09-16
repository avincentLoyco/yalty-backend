module API
  module V1
    class EmployeesController < JSONAPI::ResourceController
      include API::V1::EmployeeManagement

      skip_before_filter :setup_request, only: [:create]

      def create
        setup_employee_management
        build_employee(employee_data)
        build_employee_event(employee_event_data)
        build_employee_attributes(employee_attribute_data)
        save_employee

        render status: :no_content, nothing: true
      rescue => e
        handle_exceptions(e)
      end

      private

      def employee_data
        params.require(:data)
      end

      def employee_event_data
        employee_data.require(:relationships)
          .require(:events)
          .require(:data)
      end

      def employee_attribute_data
        employee_event_data.first
          .require(:relationships)
          .require(:employee_attributes)
          .require(:data)
      end
    end
  end
end

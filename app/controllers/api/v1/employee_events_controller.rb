module API
  module V1
    class EmployeeEventsController < JSONAPI::ResourceController
      include API::V1::EmployeeManagement

      skip_before_action :setup_request, only: [:create]

      def create
        setup_params
        load_employee(employee_data)
        build_employee_event(employee_event_data)
        build_employee_attributes(employee_attribute_data)
        save_event

        render status: :no_content, nothing: true
      rescue => e
        handle_exceptions(e)
      end

      private

      def employee_data
        employee_event_data
          .require(:relationships)
          .require(:employee)
          .require(:data)
      end

      def employee_event_data
        params.require(:data)
      end

      def employee_attribute_data
        employee_event_data
          .require(:relationships)
          .require(:employee_attributes)
          .require(:data)
      end
    end
  end
end

module API
  module V1
    class WorkingPlacesController < JSONAPI::ResourceController
      include ExceptionsHandler

      def assign_employee
        set_employees if params[:employees]
        render json: working_place.to_json(include: :employees), status: 200
      end

      private

      def working_place
        @working_place ||= Account.current.working_places.find(params[:id])
      end

      def set_employees
        params[:employees].each do |employee_id|
          working_place.employees.push(Employee.find(employee_id))
        end
        working_place.save!
      end
    end
  end
end

module Api
  module V1
    class EmployeeWorkingPlaceRepresenter < BaseRepresenter
      def complete
        {
          assignation_id: resource.id,
          assignation_type: resource_type,
          effective_at: resource.effective_at,
          effective_till: resource.effective_till
        }
          .merge(employee_json)
      end

      def employee_json
        EmployeeRepresenter.new(resource.employee).basic
      end

      def working_place_json
        complete.merge(WorkingPlaceRepresenter.new(resource.working_place).basic)
      end
    end
  end
end

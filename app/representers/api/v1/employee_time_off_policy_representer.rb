module Api::V1
  class EmployeeTimeOffPolicyRepresenter < BaseRepresenter
    def complete
      {
        id: resource.employee_id,
        assignation_type: resource_type,
        assignation_id: resource.id,
        effective_at: resource.effective_at,
        effective_till: nil
      }
    end
  end
end

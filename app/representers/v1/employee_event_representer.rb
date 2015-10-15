module V1
  class EmployeeEventRepresenter < BaseRepresenter
    def complete
      {
        effective_at: resource.effective_at,
        comment: resource.comment,
        event_type: resource.event_type
      }
        .merge(basic)
        .merge(relationship)
    end

    def relationship
      employee = EmployeeRepresenter.new(resource.employee).complete
      {
        employee: employee
      }
    end
  end
end

module Api::V1
  class EmployeeBalanceOverviewRepresenter
    pattr_initialize :resource

    def complete
      {
        category: resource.category.name,
        employee: resource.employee.id,
        result: resource.balance_result,
      }
    end
  end
end

# frozen_string_literal: true

module Employees
  class Show
    include AppDependencies[get_account_employees: "use_cases.employees.index"]

    def call(id)
      employees = get_account_employees.call
      employees.find(id)
    end
  end
end

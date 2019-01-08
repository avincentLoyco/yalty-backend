# frozen_string_literal: true

module Containers
  Models = Dry::Container::Namespace.new("models") do
    register("account") { Account }
    register("employee_time_off_policy") { EmployeeTimeOffPolicy }
    register("registered_working_time") { RegisteredWorkingTime }

    namespace "employee" do
      register("balance") { Employee::Balance }
    end
  end
end

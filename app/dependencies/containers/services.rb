# frozen_string_literal: true

module Containers
  Services = Dry::Container::Namespace.new("services") do
    namespace "employee_balance" do
      register("create_employee_balance") { CreateEmployeeBalance }
    end

    namespace "event" do
      register("create_event") { CreateEvent }
      register("update_event") { UpdateEvent }
      register("delete_event") { DeleteEvent }

      namespace "contract_ends" do
        register("create") { ContractEnds::Create }
      end
    end
  end
end

# frozen_string_literal: true

module Containers
  Services = Dry::Container::Namespace.new("services") do
    namespace "employee_balance" do
      register("create_employee_balance") { CreateEmployeeBalance }
      register("destroy_employee_balance") { DestroyEmployeeBalance }
      register("update_next_employee_balances") { UpdateNextEmployeeBalances }
    end

    namespace "employee_policy" do
      namespace "presence" do
        register("create") { EmployeePolicy::Presence::Create }
      end
    end

    namespace "event" do
      register("create_event") { CreateEvent }
      register("update_event") { UpdateEvent }
      register("delete_event") { DeleteEvent }

      register("create_etop_for_event") { CreateEtopForEvent }

      namespace "contract_ends" do
        register("create") { ContractEnds::Create }
      end
    end
  end
end

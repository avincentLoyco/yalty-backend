# frozen_string_literal: true

module Containers
  UseCases = Dry::Container::Namespace.new("use_cases") do
    namespace "employees" do
      register("index") { Employees::Index.new }
      register("show") { Employees::Show.new }
      register("destroy") { Employees::Destroy.new }

      register("assign_employee_to_all_tops") { Employees::AssignEmployeeToAllTops.new }
      register("find_unassigned_tops_for_employee") { Employees::FindUnassignedTopsForEmployee.new }
    end

    namespace "balances" do
      namespace "end_of_contract" do
        register("create") { Balances::EndOfContract::Create.new }
        register("find_and_destroy") { Balances::EndOfContract::FindAndDestroy.new }
      end
    end

    namespace "events" do
      namespace "contract_end" do
        register("assign_employee_top_to_event") {
          Events::ContractEnd::AssignEmployeeTopToEvent.new
        }
      end
    end

    namespace "time_off_categories" do
      register("find_by_name") { TimeOffCategories::FindByName.new }
    end
  end
end

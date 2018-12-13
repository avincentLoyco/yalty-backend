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
        register("find_effective_at") { Balances::EndOfContract::FindEffectiveAt.new }
      end
    end

    namespace "events" do
      namespace "adjustment" do
        register("find_adjustment_balance") { Events::Adjustment::FindAdjustmentBalance.new }
      end

      namespace "contract_end" do
        register("assign_employee_top_to_event") {
          Events::ContractEnd::AssignEmployeeTopToEvent.new
        }
        register("find_first_after_date") {
          Events::ContractEnd::FindFirstAfter.new
        }
      end
    end

    namespace "time_entries" do
      register("create") { TimeEntries::Create.new }
      register("destroy") { TimeEntries::Destroy.new }
      register("update") { TimeEntries::Update.new }
    end

    namespace "time_off_categories" do
      register("find_by_name") { TimeOffCategories::FindByName.new }
    end

    namespace "presence_days" do
      register("destroy") { PresenceDays::Destroy.new }
      register("create") { PresenceDays::Create.new }
      register("update") { PresenceDays::Update.new }
    end

    namespace "presence_policies" do
      register("create_presence_days") { PresencePolicies::CreatePresenceDays.new }
      register("create") { PresencePolicies::Create.new }
      register("destroy") { PresencePolicies::Destroy.new }
      register("update") { PresencePolicies::Update.new }
      register("update_default_full_time") { PresencePolicies::UpdateDefaultFullTime.new }
      register("verify_employees_not_assigned") do
        PresencePolicies::VerifyEmployeesNotAssigned.new
      end
      register("verify_not_default_full_time") do
        PresencePolicies::VerifyNotDefaultFullTime.new
      end
    end

    namespace "registered_working_times" do
      register("create_or_update") { RegisteredWorkingTimes::CreateOrUpdate.new }
      register("verify_part_of_employment_period") do
        RegisteredWorkingTimes::VerifyPartOfEmploymentPeriod.new
      end
    end
  end
end

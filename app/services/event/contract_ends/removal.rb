module ContractEnds
  class Removal
    UnemploymentPeriod = Struct.new(:start_date, :end_date)

    attr_implement :remove_balances, :assign_reset_resources,
      :assign_reset_balances_and_create_additions

    def call
      ActiveRecord::Base.transaction do
        remove_join_tables
        remove_time_offs
        remove_balances
        remove_work_contracts
        remove_adjustment_events
        assign_reset_resources
        move_time_offs
        assign_reset_balances_and_create_additions
      end
    end

    def remove_join_tables
      EmployeePolicy::DeleteInPeriod.call(
        period_to_delete: unemployment_period,
        join_table_types: Employee::RESOURCE_JOIN_TABLES,
        employee: employee,
        reset: false
      )
    end

    def remove_time_offs
      TimeOffs::DeleteInPeriod.call(
        period_to_delete: unemployment_period,
        employee: employee
      )
    end

    def remove_work_contracts
      DeleteTypeInPeriod.call(
        period_to_delete: unemployment_period,
        event_type: "work_contract",
        employee: employee
      )
    end

    def remove_adjustment_events
      DeleteTypeInPeriod.call(
        period_to_delete: unemployment_period,
        event_type: "adjustment_of_balances",
        employee: employee
      )
    end

    def balances_to_remove
      employee
        .employee_balances
        .not_time_off
        .where("effective_at > ?", balance_remove_date)
    end

    def balance_remove_date
      unemployment_period.start_date + 1.day + Employee::Balance::REMOVAL_OFFSET
    end

    def move_time_offs
      time_offs_to_move.map do |time_off|
        time_off.update!(end_time: unemployment_period.start_date + 1.day)
        time_off.employee_balance.update!(
          effective_at: time_off.end_time
        )
      end
    end

    def time_offs_to_move
      employee.time_offs.at_date(unemployment_period.start_date)
    end

    def employee_used_time_off_categories
      employee.employee_time_off_policies.pluck(:time_off_category_id).uniq
    end
  end
end

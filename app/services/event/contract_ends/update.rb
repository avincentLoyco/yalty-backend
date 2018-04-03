module ContractEnds
  class Update < Removal
    attr_reader :employee, :old_contract_end_date, :next_hire_date, :unemployment_period

    def self.call(employee:, new_contract_end_date:, old_contract_end_date:)
      new(
        employee: employee,
        new_contract_end_date: new_contract_end_date,
        old_contract_end_date: old_contract_end_date,
      ).call
    end

    def initialize(employee:, new_contract_end_date:, old_contract_end_date:)
      @employee              = employee
      @old_contract_end_date = old_contract_end_date + 1
      @next_hire_date        = find_next_hire_date(new_contract_end_date) || Float::INFINITY
      @unemployment_period   = UnemploymentPeriod.new(new_contract_end_date, next_hire_date)
    end

    def call
      remove_old_reset_join_tables
      super
    end

    private

    def remove_old_reset_join_tables
      Employee::RESOURCE_JOIN_TABLES.each do |table_name|
        employee.send(table_name).with_reset.where(effective_at: old_contract_end_date).delete_all
      end

      employee.employee_balances.where(
        "effective_at::date = ? AND balance_type = ?", old_contract_end_date, "reset"
      ).delete_all
    end

    def remove_balances
      balances = balances_to_remove

      balances = balances.where("effective_at < ?", next_hire_date) if next_hire_date.present?
      balances.delete_all
    end

    def assign_reset_resources
      %w(presence_policies working_places time_off_policies).map do |resources_name|
        AssignResetJoinTable.new(resources_name, employee, nil, unemployment_period.start_date).call
      end
    end

    def assign_reset_balances_and_create_additions
      employee_used_time_off_categories.map do |category_id|
        AssignResetEmployeeBalance.new(
          employee, category_id, unemployment_period.start_date, old_contract_end_date
        ).call
        next unless unemployment_period.start_date > old_contract_end_date
        etop = employee.active_policy_in_category_at_date(category_id, old_contract_end_date)
        ManageEmployeeBalanceAdditions.new(etop).call
      end
    end

    def find_next_hire_date(new_contract_end_date)
      employee
        .events
        .hired
        .order(:effective_at)
        .find_by("effective_at > ?", new_contract_end_date)
        .try(:effective_at)
    end
  end
end

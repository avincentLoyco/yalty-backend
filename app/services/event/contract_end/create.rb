# module Event
module ContractEnd
  class Create < ContractEnd::Removal
    attr_reader :employee, :unemployment_period

    def self.call(employee:, contract_end_date:)
      new(employee: employee, contract_end_date: contract_end_date).call
    end

    def initialize(employee:, contract_end_date:)
      @employee             = employee
      @unemployment_period  = UnemploymentPeriod.new(contract_end_date, Float::INFINITY)
    end

    def call
      super
    end

    private

    def remove_balances
      balances_to_remove.delete_all
    end

    def assign_reset_resources
      %w(presence_policies working_places time_off_policies).map do |resources_name|
        AssignResetJoinTable.new(resources_name, employee, nil, unemployment_period.start_date).call
      end
    end

    def assign_reset_balances_and_create_additions
      employee_used_time_off_categories.map do |category_id|
        AssignResetEmployeeBalance.new(
          employee,
          category_id,
          unemployment_period.start_date,
          nil
        ).call
      end
    end
  end
end

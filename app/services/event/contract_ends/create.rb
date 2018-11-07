# module Event
module ContractEnds
  class Create < Removal
    attr_reader :employee, :unemployment_period, :event_id, :vacation_toc, :contract_end_date

    def self.call(employee:, contract_end_date:, event_id:)
      new(employee: employee, contract_end_date: contract_end_date, event_id: event_id).call
    end

    def initialize(employee:, contract_end_date:, event_id:)
      @employee             = employee
      @event_id             = event_id
      @contract_end_date    = contract_end_date
      @unemployment_period  = UnemploymentPeriod.new(contract_end_date, Float::INFINITY)
      @vacation_toc         = employee.account.time_off_categories.find_by(name: "vacation")
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

    def assign_end_of_contract_balance
      effective_at = eoc_balance_effective_at(vacation_toc.id, contract_end_date)

      # NOTE: Most probably there should always be at least one vacation balance for an employee.
      # This check was added to handle random situations and to avoid fixing a lot of controller
      # specs
      return unless effective_at

      Balances::EndOfContract::Create.new.call(
        vacation_toc_id: vacation_toc.id,
        employee: employee,
        effective_at: effective_at,
        event_id: event_id
      )
    end

    def assign_reset_balances_and_create_additions
      employee_used_time_off_categories.map do |category_id|
        AssignResetEmployeeBalance.new(
          employee,
          category_id,
          unemployment_period.start_date,
          nil,
        ).call
      end
    end
  end
end

module EmployeePolicy
  module WorkingPlace
    module Duplicates
      class Destroy
        attr_reader :employee_working_place, :employee, :effective_at, :working_place,
          :employee_working_places, :contract_end

        def self.call(employee_working_place)
          new(employee_working_place).call
        end

        def initialize(employee_working_place)
          @employee_working_place  = employee_working_place
          @employee                = employee_working_place.employee
          @effective_at            = employee_working_place.effective_at
          @working_place           = employee_working_place.working_place
          @employee_working_places = employee.employee_working_places
          @contract_end            = employee.contract_end_for(effective_at)
        end

        def call
          if contract_end.eql?(effective_at - 1.day)
            ::ContractEnds::Update.call(
              employee: employee,
              new_contract_end_date: contract_end,
              old_contract_end_date: contract_end,
              event_id: employee.event_at(date: contract_end, type: "contract_end")
            )
          else
            duplicated = FindSequenceJoinTableInTime.new(
              employee_working_places, nil, working_place, employee_working_place
            ).call
            duplicated.map(&:destroy!)
          end
        end
      end
    end
  end
end

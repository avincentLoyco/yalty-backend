module Events
  module Adjustment
    module Balances
      def adjustment_balance
        @adjustment_balance ||=
          Employee::Balance.find_by!(
            time_off_category_id: event.account.vacation_category.id,
            employee_id: event.employee_id,
            effective_at: old_effective_at + Employee::Balance::MANUAL_ADJUSTMENT_OFFSET
          )
      end
    end
  end
end

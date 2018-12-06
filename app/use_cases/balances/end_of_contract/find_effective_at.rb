# TODO: This logic should be moved to a repository/command in future refactor

module Balances
  module EndOfContract
    class FindEffectiveAt
      def call(employee:, vacation_toc_id:, contract_end_date:)
        # NOTE: Find last vacation balance before contract end date
        # If employee has no time offs, last vacation balance should be an assignation balance
        last_vacation_balance = employee
          .employee_balances.where(
            "time_off_category_id = ? AND effective_at <= ?", vacation_toc_id, contract_end_date)
          .order(:effective_at)
          .last

        return unless last_vacation_balance
        last_vacation_balance
          .effective_at.to_date.to_time(:utc) + Employee::Balance::END_OF_CONTRACT_OFFSET
      end
    end
  end
end

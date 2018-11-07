# TODO: This logic should be moved to a repository/command in future refactor

module Balances
  module EndOfContract
    class FindAndDestroy
      def call(employee:, eoc_date:)
        eoc_balance = employee
          .employee_balances
          .where(
            "balance_type = ? AND effective_at < ?", "end_of_contract", eoc_date)
          .order(:effective_at)
          .last

        eoc_balance&.destroy!
      end
    end
  end
end

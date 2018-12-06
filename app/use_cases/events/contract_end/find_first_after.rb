module Events
  module ContractEnd
    class FindFirstAfter
      def call(effective_at:, employee:)
        return unless employee

        employee
          .events
          .contract_ends
          .where("effective_at > ?", effective_at)
          .order(:effective_at)
          .first
      end
    end
  end
end

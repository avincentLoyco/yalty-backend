module BalanceOverview
  class Period
    class << self
      def build(category:, employee:, date:)
        new(category: category, employee: employee, date: date)
      end
    end

    pattr_initialize [:employee!, :category!, :date!]

    attr_reader :category, :employee

    def balance_result
      @balance_result ||=
        BalanceCalculator.call(daterange: daterange, category: category, employee: employee)
    end

    def expiring_balances
      balances.where(balance_type: :removal).group(:effective_at).sum(:resource_amount)
    end

    private

    def daterange
      @borders ||= DateRangeFinder.call(employee, category, date)
    end

    def balances
      @balances ||=
        employee.employee_balances.in_category(category.id).between(start_date, end_date)
    end
  end
end

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

    private

    def daterange
      @borders ||= DateRangeFinder.call(employee, category, date)
    end
  end
end

module BalanceOverview
  class Generate
    class << self
      def call(employee, category: :all, date: Time.zone.today)
        new(employee, category: category, date: date).call
      end
    end

    pattr_initialize :employee, [:category, :date!, :show_expiring]

    delegate :time_off_categories, to: :employee, prefix: true

    def call
      filtered_employee_time_off_categories.map(&method(:period_for))
    end

    private

    def filtered_employee_time_off_categories
      employee_time_off_categories.where(category_filter)
    end

    def period_for(category)
      period_class.build(category: category, employee: employee, date: date)
    end

    def category_filter
      { name: category } unless category == :all
    end

    def period_class
      employee_hired? ? Period : EmptyPeriod
    end

    def employee_hired?
      employee.contract_periods_include?(date)
    end
  end
end

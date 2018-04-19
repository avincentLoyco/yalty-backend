module BalanceOverview
  class CurrentTimeOffPolicy
    pattr_initialize :time_off_policy, :date

    delegate :start_day, :start_month, to: :time_off_policy

    def start_date
      Date.new(start_year, start_month, start_day)
    end

    def end_date
      start_date + 1.year
    end

    private

    def start_year
      Date.new(date.year, start_month, start_day) <= date ? date.year : date.year - 1
    end
  end
end

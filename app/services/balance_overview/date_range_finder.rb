module BalanceOverview
  class DateRangeFinder
    method_object :employee, :category, :date

    delegate :time_off_policy, to: :current_etop
    delegate :employee_time_off_policies, to: :employee

    def call
      return empty_daterange if current_etop.blank?
      start_date..end_date
    end

    private

    def start_date
      [current_etop.effective_at, current_time_off_policy.start_date].compact.max
    end

    def end_date
      [current_time_off_policy.end_date, contract_end_date].compact.min
    end

    def contract_end_date
      employee.contract_end_for(date)
    end

    def current_etop
      @current_etop ||= policies_in_category.not_reset.assigned_at(date).first
    end

    def policies_in_category
      employee_time_off_policies.in_category(category.id)
    end

    def current_time_off_policy
      @current_time_off_policy ||= CurrentTimeOffPolicy.new(time_off_policy, date)
    end

    def empty_daterange
      OpenStruct.new(min: nil, max: nil, empty?: true)
    end
  end
end

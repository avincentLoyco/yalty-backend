class GenerateBalanceOverview
  def initialize(employee_id)
    @employee = Employee.find(employee_id)
    @active_categories = find_employees_categories
  end

  def call
    find_active_periods_per_category.map do |category_hash|
      result_category_hash = empty_category_hash
      category_hash.each do |category_id, periods|
        result_category_hash[:category] = @active_categories.find_by(id: category_id).name
        result_category_hash[:periods] += periods.map do |period|
          period_important_info =
            {
              type: period[:type],
              start_date: period[:start_date],
              validity_date: period[:validity_date]
            }
          result_calculations = CalculatePeriodOverview.new(period, @employee.id, category_id).call
          period_important_info.merge(result_calculations)
        end
      end
      result_category_hash[:periods] = overrided_hash_for_category(result_category_hash[:periods])
      result_category_hash
    end
  end

  private

  def empty_category_hash
    {
      employee: @employee.id,
      category: nil,
      periods: []
    }
  end

  def find_employees_categories
    categories_id = @employee.employee_time_off_policies.pluck(:time_off_category_id).uniq
    TimeOffCategory.where(id: categories_id).order(:name)
  end

  def find_active_periods_per_category
    @active_categories.map do |category|
      current_period = find_period_if_balances_present(category, Time.zone.today)
      next_period = find_next_period(category, current_period)
      active_periods = find_active_periods_from_balances(category, current_period)

      { category.id => [active_periods, current_period, next_period].flatten.compact }
    end
  end

  def find_next_period(category, current_period)
    next_active_date =
      if current_period
        current_period[:end_date] + 1.day
      else
        EmployeeTimeOffPolicy
          .not_assigned_at(Time.zone.today)
          .by_employee_in_category(@employee.id, category.id)
          .first
          .try(:effective_at)
      end

    find_period_if_balances_present(category, next_active_date) if next_active_date
  end

  def find_active_periods_from_balances(category, current_period)
    return [] unless current_period.to_h[:start_date].present?
    active_period_balances(category, current_period).map do |balance|
      find_period(category, balance.effective_at)
    end.uniq
  end

  def active_period_balances(category, current_period)
    current_period_start = current_period.to_h[:start_date]
    balances =
      @employee
      .employee_balances
      .where(time_off_category: category)
      .where('effective_at < ?', current_period_start)
      .order(:effective_at)
    return active_balances(balances) unless current_period[:validity_date]
    balances.where('validity_date >= ?', current_period_start)
  end

  def find_period_if_balances_present(category, date)
    period = find_period(category, date)
    return unless period.present?
    balances_in_period =
      @employee
      .employee_balances
      .in_category(category)
      .between(period[:start_date], period[:end_date])
    period if balances_in_period.present?
  end

  def find_period(category, date)
    PeriodInformationFinderByCategory.new(@employee, category).find_period_for_date(date)
  end

  def overrided_hash_for_category(period)
    return [] unless period.present?
    OverrideAmountTakenForBalancer.new(period).call
  end

  def active_balances(balances)
    positive = balances.where('resource_amount > 0 OR manual_amount > 0').order(:effective_at)
    negative =
      balances.pluck(:manual_amount, :resource_amount).flatten.select { |value| value < 0 }.sum
    positive.map do |balance|
      balance_positive_amount =
        balance.slice(:resource_amount, :manual_amount).values.select { |value| value > 0 }.sum
      break if balance_positive_amount + negative > 0
      negative += balance_positive_amount
      positive -= [balance]
    end
    positive
  end
end

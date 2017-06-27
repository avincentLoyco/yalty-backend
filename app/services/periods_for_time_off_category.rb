class PeriodsForTimeOffCategory
  attr_reader :employee, :time_off_category, :periods

  def initialize(employee, time_off_category)
    @employee = employee
    @time_off_category = time_off_category
    @periods = []
  end

  def call
    prepare_category_hash
    periods
  end

  private

  def in_category
    @in_category ||=
      employee
      .employee_time_off_policies
      .where(time_off_category: time_off_category)
      .order(:effective_at)
      .includes(:time_off_policy)
  end

  def prepare_category_hash
    in_category.not_reset.map do |etop|
      next unless periods.blank? || periods.last[:effective_till] &&
          periods.last[:effective_till] < etop.effective_at
      periods.push(
        effective_since: etop.effective_at,
        effective_till: find_contract_end(etop.effective_at)
      )
    end
  end

  def find_contract_end(effective_at)
    contract_end_for = employee.contract_end_for(effective_at)
    return contract_end_for if contract_end_for.nil? || contract_end_for >= effective_at
    employee.contract_end_for(effective_at + 1.day)
  end
end

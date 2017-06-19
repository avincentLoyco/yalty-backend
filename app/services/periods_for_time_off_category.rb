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
        effective_till: employee.contract_end_for(etop.effective_at)
      )
    end
  end
end

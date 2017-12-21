class Adjustments::Calculate
  attr_reader :employee, :standard_day_duration, :event

  MIGRATION_DATE = Rails.configuration.migration_date

  def self.call(event_id)
    new(event_id).call
  end

  # when running specs we get DEPRECATION WARNING
  # reason: https://github.com/rails/rails/issues/21945
  def initialize(event_id)
    @event                 = Employee::Event.find(event_id)
    @employee              = Employee.find(event.employee_id)
    @standard_day_duration = employee.account.presence_policies.full_time.standard_day_duration
  end

  def call
    adjustment = if event.event_type.eql?('hired') || first_work_contract?
                   Adjustments::Calculator::Hired.call(
                     annual_allowance(current_etop), event.effective_at
                   )
                 elsif event.event_type.eql?('contract_end')
                   Adjustments::Calculator::ContractEnd.call(
                     annual_allowance(current_etop), event.effective_at
                   )
                 elsif event.event_type.eql?('work_contract')
                   Adjustments::Calculator::WorkContract.call(
                     annual_allowance(current_etop), annual_allowance(previous_etop),
                     event.effective_at
                   )
                 end
    (adjustment * standard_day_duration).round
  end

  private

  def first_work_contract?
    event.event_type.eql?('work_contract') && employee_created_before_migration? &&
      event_after_migration? && first_work_contract_after_migration?
  end

  def first_work_contract_after_migration?
    employee
      .events
      .where('event_type = ? AND effective_at >= ? AND effective_at < ?', 'work_contract',
             MIGRATION_DATE, event.effective_at).empty?
  end

  def employee_created_before_migration?
    employee.created_at < MIGRATION_DATE
  end

  def event_after_migration?
    event.effective_at >= MIGRATION_DATE
  end

  def annual_allowance(etop)
    (etop.time_off_policy.amount / standard_day_duration) * etop.occupation_rate
  end

  def current_etop
    event.employee_time_off_policy
  end

  def previous_etop
    all_vacation_etops.last
  end

  # Maybe add method that looks through vacation or 'name' policies in ETOP model
  # as a scope, then we can chain methods
  # IDEA
  # EmployeeTimeOffPolicy.by_category_name('vacation').not_reset.assigned_before(date)
  # Problem: scope can return all records if condition is not met
  # Specs would be aloooot easier to write
  def all_vacation_etops
    employee.employee_time_off_policies.select do |etop|
      etop.time_off_category.name == 'vacation' && !etop.time_off_policy.reset &&
        etop.effective_at < event.effective_at
    end
  end
end

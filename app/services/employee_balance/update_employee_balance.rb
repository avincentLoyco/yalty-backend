class UpdateEmployeeBalance
  include API::V1::Exceptions
  attr_reader :employee_balance, :time_off, :options, :current_date

  def initialize(employee_balance, options = {})
    @employee_balance = employee_balance.reload
    @time_off = employee_balance.time_off
    @options = options
    @current_date = employee_balance.validity_date
  end

  def call
    update_attributes
    recalculate_amount
    update_status
    manage_removal
    save!
  end

  private

  def manage_removal
    ManageEmployeeBalanceRemoval.new(
      options[:validity_date] || employee_balance.validity_date, employee_balance, current_date
    ).call
  end

  def update_attributes
    employee_balance.assign_attributes(options)
    employee_balance.validity_date = options[:validity_date] || find_validity_date
  end

  def recalculate_amount
    return unless employee_balance.balance_type.eql?('reset') ||
        employee_balance.balance_credit_additions.present? || counter_and_addition?
    employee_balance.calculate_removal_amount
  end

  def update_status
    employee_balance.being_processed = false
  end

  def save!
    if employee_balance.valid?
      employee_balance.save!
      employee_balance.reload.balance_credit_removal.try(:save!)
    else
      messages = employee_balance.errors.messages

      raise InvalidResourcesError.new(employee_balance, messages)
    end
  end

  def last_balance
    RelativeEmployeeBalancesFinder.new(employee_balance).previous_balances.last.try(:balance)
  end

  def counter_and_addition?
    employee_balance.time_off_policy&.counter? && employee_balance.balance_type.eql?('addition')
  end

  def find_validity_date
    return if employee_balance.balance_type.in?(%w(reset removal))
    etop = employee_balance.employee_time_off_policy
    return unless etop.time_off_policy.end_month.present? && etop.time_off_policy.end_day.present?
    if options[:effective_at] || employee_balance.balance_type.eql?('time_off') ||
        employee_balance.validity_date&.strftime('%S').eql?('03')
      RelatedPolicyPeriod
        .new(etop)
        .validity_date_for_balance_at(employee_balance.effective_at, employee_balance.balance_type)
    else
      employee_balance.validity_date
    end
  end
end

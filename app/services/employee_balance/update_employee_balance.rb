class UpdateEmployeeBalance
  include API::V1::Exceptions
  attr_reader :employee_balance, :options, :previous_validity_date

  def initialize(employee_balance, options = {})
    @employee_balance = employee_balance
    @options = options
    @previous_validity_date = employee_balance.validity_date
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
      new_validity_day, employee_balance, previous_validity_date
    ).call
  end

  def new_validity_day
    options[:validity_date] || employee_balance.validity_date
  end

  def update_attributes
    employee_balance.assign_attributes(options)
    employee_balance.validity_date = options[:validity_date] || find_validity_date
  end

  def recalculate_amount
    return unless employee_balance.balance_type.eql?("reset") ||
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
    employee_balance.time_off_policy&.counter? && employee_balance.balance_type.eql?("addition")
  end

  def find_validity_date
    return if employee_balance.balance_type.in?(%w(reset removal)) || !employee_balance.valid?
    etop = employee_balance.employee_time_off_policy
    return unless etop.time_off_policy.end_month.present? && etop.time_off_policy.end_day.present?
    RelatedPolicyPeriod
      .new(etop)
      .validity_date_for_balance_at(employee_balance.effective_at, employee_balance.balance_type)
  end
end

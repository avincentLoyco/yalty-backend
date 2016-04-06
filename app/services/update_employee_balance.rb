class UpdateEmployeeBalance
  include API::V1::Exceptions
  attr_reader :employee_balance, :time_off, :options

  def initialize(employee_balance, options = {})
    @employee_balance = employee_balance
    @time_off = employee_balance.time_off
    @options = options
  end

  def call
    update_attributes unless options.blank?
    ManageRemoval.new(options[:validity_date], employee_balance).call if options[:validity_date]
    recalculate_amount
    update_status
    save!
  end

  private

  def update_attributes
    employee_balance.assign_attributes(options)
  end

  def recalculate_amount
    return unless employee_balance.balance_credit_addition || counter_and_addition? || time_off
    if time_off
      employee_balance.amount = time_off.balance
    else
      employee_balance.amount =
        employee_balance.time_off_policy.counter? ? counter_recalculation : balancer_recalculation
    end
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

  def counter_recalculation
    0 - last_balance.to_i
  end

  def balancer_recalculation
    employee_balance.calculate_removal_amount
  end

  def last_balance
    employee_balance.previous_balances.last.try(:balance)
  end

  def counter_and_addition?
    employee_balance.time_off_policy.counter? && employee_balance.policy_credit_addition
  end
end

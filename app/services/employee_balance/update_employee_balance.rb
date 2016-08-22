class UpdateEmployeeBalance
  include API::V1::Exceptions
  attr_reader :employee_balance, :time_off, :options, :current_date

  def initialize(employee_balance, options = {})
    @employee_balance = employee_balance
    @time_off = employee_balance.time_off
    @options = options
    @current_date = employee_balance.validity_date
  end

  def call
    update_attributes unless options.blank?
    recalculate_amount unless employee_balance.reset_balance
    update_status
    save!
    manage_removal if options[:validity_date]
  end

  private

  def manage_removal
    ManageEmployeeBalanceRemoval.new(options[:validity_date], employee_balance, current_date).call
  end

  def update_attributes
    employee_balance.assign_attributes(options)
  end

  def recalculate_amount
    return unless employee_balance.balance_credit_addition || counter_and_addition? || time_off
    if time_off
      employee_balance.resource_amount = time_off.balance
    else
      employee_balance.resource_amount =
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
    RelativeEmployeeBalancesFinder.new(employee_balance).previous_balances.last.try(:balance)
  end

  def counter_and_addition?
    employee_balance.time_off_policy.counter? && employee_balance.policy_credit_addition
  end
end

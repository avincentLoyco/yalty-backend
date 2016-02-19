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
    recalculate_amount if employee_balance.balance_credit_addition
    update_status

    save!
  end

  private

  def update_attributes
    employee_balance.assign_attributes(options)
  end

  def recalculate_amount
    employee_balance.amount =
      employee_balance.time_off_policy.counter? ? counter_recalculation : balancer_recalculation
  end

  def update_status
    employee_balance.beeing_processed = false
  end

  def save!
    if employee_balance.valid?
      employee_balance.save!
    else
      messages = employee_balance.errors.messages

      fail InvalidResourcesError.new(employee_balance, messages)
    end
  end

  def counter_recalculation
    0 - last_balance
  end

  def balancer_recalculation
    employee_balance.calculate_removal_amount
  end

  def last_balance
    employee_balance.employee.last_balance_in_policy(employee_balance.time_off_policy_id)
  end
end

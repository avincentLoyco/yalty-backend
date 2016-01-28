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
    update_status

    save!
  end

  def update_attributes
    employee_balance.assign_attributes(options)
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
end

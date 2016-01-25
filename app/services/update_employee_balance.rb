class UpdateEmployeeBalance
  attr_reader :employee_balance, :time_off, :amount

  def initialize(employee_balance, amount = nil)
    @employee_balance = employee_balance
    @time_off = employee_balance.time_off
    @amount = amount
  end

  def call
    update_amount unless amount.blank?
    recalculate_balance
    update_status

    save!
  end

  def update_amount
    employee_balance.amount = amount
  end

  def recalculate_balance
    employee_balance.calculate_and_set_balance
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

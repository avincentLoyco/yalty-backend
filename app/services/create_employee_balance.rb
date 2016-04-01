class CreateEmployeeBalance
  include API::V1::Exceptions
  attr_reader :category, :employee, :amount, :employee_balance,
    :account, :time_off, :options, :balance_removal

  def initialize(category_id, employee_id, account_id, amount, options = {})
    @options = options
    @account = Account.find(account_id)
    @category = account.time_off_categories.find(category_id)
    @employee = account.employees.find(employee_id)
    @amount = amount
    @employee_balance = nil
    @balance_removal = nil
    @time_off = time_off
  end

  def call
    ActiveRecord::Base.transaction do
      build_employee_balance
      build_employee_balance_removal if validity_date.present? && validity_date <= Time.zone.today
      calculate_amount if employee_balance.time_off_policy.present?
      save!

      update_next_employee_balances
    end
    balance_removal ? [employee_balance, balance_removal] : [employee_balance]
  end

  def build_employee_balance
    @employee_balance = Employee::Balance.new(balance_params)
  end

  def build_employee_balance_removal
    @balance_removal = employee_balance.build_balance_credit_removal(balance_removal_params)
  end

  def save!
    if employee_balance.valid?
      employee_balance.save!
      employee_balance.balance_credit_addition.save! if employee_balance.policy_credit_removal
      balance_removal.try(:save!)
    else
      messages = employee_balance.errors.messages

      raise InvalidResourcesError.new(employee_balance, messages)
    end
  end

  private

  def common_params
    {
      amount: amount,
      employee: employee,
      time_off: time_off,
      time_off_category: category
    }
  end

  def balance_params
    {
      validity_date: validity_date,
      effective_at: effective_at,
      balance_credit_addition: balance_credit_addition,
      policy_credit_addition: options[:policy_credit_addition] || false
    }.merge(common_params)
  end

  def balance_removal_params
    common_params.merge(effective_at: employee_balance.validity_date)
  end

  def time_off
    options.key?(:time_off_id) ? employee.time_offs.find(options[:time_off_id]) : nil
  end

  def effective_at
    options[:effective_at]
  end

  def validity_date
    DateTime.parse(options[:validity_date]).in_time_zone
  rescue
    nil
  end

  def balance_credit_addition
    return nil unless options[:balance_credit_addition_id]
    Employee::Balance.find(options[:balance_credit_addition_id])
  end

  def calculate_amount
    return unless balancer_removal? || counter_addition?
    if balance_removal
      balance_removal.calculate_removal_amount(employee_balance)
    else
      employee_balance.calculate_removal_amount
    end
  end

  def update_next_employee_balances
    return if only_in_balance_period? || options[:skip_update]
    balances_ids = employee_balance.later_balances_ids
    update_being_processed_status(balances_ids)
    UpdateBalanceJob.perform_later(employee_balance.id)
  end

  def only_in_balance_period?
    employee_balance.last_in_category? || balance_removal.try(:last_in_category?) &&
      Employee::Balance.where(effective_at:
        employee_balance.effective_at...balance_removal.effective_at).count == 1
  end

  def update_being_processed_status(balances_ids)
    Employee::Balance.where(id: balances_ids).update_all(being_processed: true)
    TimeOff.find(time_off.id).update(being_processed: true) if time_off
  end

  def balancer_removal?
    balance_removal || employee_balance.balance_credit_addition.present?
  end

  def counter_addition?
    employee_balance.policy_credit_addition && employee_balance.time_off_policy.counter?
  end
end

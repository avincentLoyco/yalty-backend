class CreateEmployeeBalance
  include API::V1::Exceptions
  attr_reader :category, :employee, :resource_amount, :employee_balance,
    :account, :time_off, :options, :balance_removal

  def initialize(category_id, employee_id, account_id, options = {})
    @options = options
    @account = Account.find(account_id)
    @category = account.time_off_categories.find(category_id)
    @employee = account.employees.find(employee_id)
    @employee_balance = nil
    @balance_removal = nil
    @time_off = time_off
  end

  def call
    ActiveRecord::Base.transaction do
      build_employee_balance
      valid_balance?
      build_employee_balance_removal if validity_date.present? && validity_date <= Time.zone.today
      calculate_amount if employee_balance.time_off_policy.present?
      save!
      update_next_employee_balances
    end
    balance_removal ? [employee_balance, balance_removal] : [employee_balance]
  end

  def build_employee_balance
    @employee_balance = Employee::Balance.new(balance_params)
    return unless options[:balance_credit_addition_id]
    employee_balance.balance_credit_additions <<
      Employee::Balance.find(options[:balance_credit_addition_id])
  end

  def build_employee_balance_removal
    @balance_removal =
      Employee::Balance
      .removal_at_date(employee.id, category.id, employee_balance.validity_date.to_date)
      .first_or_initialize
    balance_removal.balance_credit_additions << [employee_balance]
  end

  def save!
    employee_balance.save!
    employee_balance.balance_credit_additions.map(&:save!) if employee_balance.balance_credit_additions.present?
    balance_removal.try(:save!)
  end

  private

  def valid_balance?
    return if employee_balance.valid? || balancer_removal? || counter_addition?
    messages = employee_balance.errors.messages
    raise InvalidResourcesError.new(employee_balance, messages)
  end

  def common_params
    [
      {
        employee: employee,
        time_off:  options.key?(:time_off_id) ? employee.time_offs.find(options[:time_off_id]) : nil,
        time_off_category: category,
      },
      manual_amount_param,
      resource_amount_param
    ].inject(:merge)
  end

  def balance_params
    {
      validity_date: validity_date,
      effective_at: options[:effective_at],
      policy_credit_addition: options[:policy_credit_addition] || false,
      reset_balance: options[:reset_balance] || false
    }.merge(common_params)
  end

  def manual_amount_param
    return {} unless options.key?(:manual_amount)
    { manual_amount: options[:manual_amount] }
  end

  def resource_amount_param
    return {} unless options.key?(:resource_amount)
    { resource_amount: options[:resource_amount] }
  end

  def validity_date
    DateTime.parse(options[:validity_date].to_s).in_time_zone
  rescue
    nil
  end

  def balance_credit_additions
    return unless options[:balance_credit_addition_id]
    [Employee::Balance.find(options[:balance_credit_addition_id])]
  end

  def calculate_amount
    return unless employee_balance.balance_credit_additions.present? || counter_addition?
    if balance_removal
      balance_removal.calculate_removal_amount([employee_balance])
    else
      employee_balance.calculate_removal_amount
    end
  end

  def update_next_employee_balances
    return if only_in_balance_period? || options[:skip_update]
    PrepareEmployeeBalancesToUpdate.new(employee_balance).call
    UpdateBalanceJob.perform_later(employee_balance.id)
  end

  def only_in_balance_period?
    employee_balance.last_in_category? || balance_removal.try(:last_in_category?) &&
      Employee::Balance.where(effective_at:
        employee_balance.effective_at...balance_removal.effective_at).count == 1
  end

  def balancer_removal?
    balance_removal || employee_balance.balance_credit_additions.present?
  end

  def counter_addition?
    employee_balance.policy_credit_addition && employee_balance.time_off_policy.counter?
  end
end

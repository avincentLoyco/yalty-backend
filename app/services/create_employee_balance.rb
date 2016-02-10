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
      build_employee_balance_removal if validity_date.present? && validity_date <= Date.today
      calculate_amount
      save!

      update_next_employee_balances
    end
    balance_removal ? [employee_balance, balance_removal] : [employee_balance]
  end

  def find_time_off_policy
    @time_off_policy = employee.active_policy_in_category(category.id)
  end

  def build_employee_balance
    @employee_balance = Employee::Balance.new(employee_balance_params)
  end

  def build_employee_balance_removal
    @balance_removal = employee_balance.build_balance_credit_removal(employee_balance_removal_params)
  end

  def save!
    if employee_balance.valid?
      employee_balance.save!
      employee_balance.balance_credit_addition.save! if employee_balance.policy_credit_removal
      balance_removal.try(:save!)
    else
      messages = employee_balance.errors.messages

      fail InvalidResourcesError.new(employee_balance, messages)
    end
  end

  private

  def common_params
    {
      employee: employee,
      time_off: time_off,
      time_off_category: category,
      time_off_policy: time_off_policy
    }
  end

  def employee_balance_params
    {
      amount: find_amount,
      validity_date: validity_date,
      effective_at: effective_at,
      balance_credit_addition: balance_credit_addition
    }.merge(common_params)
  end

  def employee_balance_removal_params
    {
      effective_at: employee_balance.validity_date,
    }.merge(common_params)
  end

  def time_off
    options.has_key?(:time_off_id) ? employee.time_offs.find(options[:time_off_id]) : nil
  end

  def find_amount
    return amount unless balance_credit_addition && time_off_policy
    balance_credit_addition.calculate_removal_amount(balance_credit_addition)
  end

  def effective_at
    return nil unless options.has_key?(:effective_at) || time_off
    time_off ? time_off.start_time : options.delete(:effective_at)
  end

  def time_off_policy
    employee.active_policy_in_category(category.id)
  end

  def validity_date
    DateTime.parse(options[:validity_date]) rescue nil
  end

  def balance_credit_addition
    return nil unless options[:balance_credit_addition_id]
    Employee::Balance.find(options[:balance_credit_addition_id])
  end

  def calculate_amount
    return unless balance_removal || employee_balance.policy_credit_removal
    balance_removal ? balance_removal.calculate_removal_amount(employee_balance) :
    employee_balance.calculate_removal_amount
  end

  def update_next_employee_balances
    return if only_in_balance_period? || options[:skip_update]
    balances_ids = employee_balance.later_balances_ids
    update_beeing_processed_status(balances_ids)
    UpdateBalanceJob.perform_later(employee_balance.id)
  end

  def only_in_balance_period?
    employee_balance.last_in_policy? || balance_removal.try(:last_in_policy?) &&
      Employee::Balance.where(effective_at:
        employee_balance.effective_at...balance_removal.effective_at).count == 1
  end

  def update_beeing_processed_status(balances_ids)
    Employee::Balance.where(id: balances_ids).update_all(beeing_processed: true)
    TimeOff.find(time_off.id).update(beeing_processed: true) if time_off
  end
end

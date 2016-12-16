class CreateEmployeeBalance
  include API::V1::Exceptions
  attr_reader :category, :employee, :resource_amount, :employee_balance,
    :account, :options, :balance_removal, :active_balance

  def initialize(category_id, employee_id, account_id, options = {})
    @options = options
    @account = Account.find(account_id)
    @category = account.time_off_categories.find(category_id)
    @employee = account.employees.find(employee_id)
    @active_balance = find_active_assignation_balance_for_date
  end

  def call
    ActiveRecord::Base.transaction do
      assign_employee_balance
      valid_balance?
      build_employee_balance_removal if balance_is_not_removal_and_has_validity_date?
      calculate_amount if employee_balance.time_off_policy.present?
      save!
      update_next_employee_balances
    end
    balance_removal ? [employee_balance, balance_removal] : [employee_balance]
  end

  def assign_employee_balance
    @employee_balance = build_or_update_employee_balance
    return unless options[:balance_credit_additions]
    employee_balance.balance_credit_additions << options[:balance_credit_additions]
  end

  def build_or_update_employee_balance
    return Employee::Balance.new(balance_params) unless active_balance
    active_balance.tap { |balance| balance.assign_attributes(balance_params) }
  end

  def build_employee_balance_removal
    @balance_removal =
      Employee::Balance
      .removal_at_date(employee.id, category.id, employee_balance.validity_date).first
    @balance_removal ||=
      Employee::Balance.new(
        employee_id: employee.id,
        time_off_category_id: category.id,
        effective_at: employee_balance.validity_date
      )

    balance_removal.balance_credit_additions << [employee_balance]
  end

  def save!
    employee_balance.save!
    if employee_balance.balance_credit_additions.present?
      employee_balance.balance_credit_additions.map(&:save!)
    end

    balance_removal.try(:save!)
  end

  private

  def find_active_assignation_balance_for_date
    return if options[:time_off_id] || options[:effective_at].blank?
    Employee::Balance
      .employee_balances(employee.id, category.id)
      .where(effective_at: options[:effective_at])
      .where(time_off_id: nil)
      .first
  end

  def active_policy_and_date_match?
    active_policy = employee.active_policy_in_category_at_date(category.id, options[:effective_at])
    return unless active_policy.present?
    effective_at_with_seconds =
      active_policy.effective_at + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET
    effective_at_with_seconds == options[:effective_at]
  end

  def valid_balance?
    return if employee_balance.valid? || balancer_removal? || counter_addition?
    messages = employee_balance.errors.messages
    raise InvalidResourcesError.new(employee_balance, messages)
  end

  def common_params
    {
      employee: employee,
      time_off:  options.key?(:time_off_id) ? employee.time_offs.find(options[:time_off_id]) : nil,
      time_off_category: category,
      manual_amount: manual_amount,
      resource_amount: options.key?(:resource_amount) ? options[:resource_amount] : 0
    }
  end

  def balance_params
    {
      validity_date: validity_date,
      effective_at: options[:effective_at],
      policy_credit_addition: options[:policy_credit_addition] || false,
      reset_balance: options[:reset_balance] || false
    }.merge(common_params)
  end

  def manual_amount
    return options[:manual_amount] if options.key?(:manual_amount)
    active_balance ? active_balance[:manual_amount] : 0
  end

  def validity_date
    DateTime.parse(options[:validity_date].to_s).in_time_zone
  rescue
    nil
  end

  def calculate_amount
    return unless employee_balance.balance_credit_additions.present? || counter_addition? ||
        balance_removal.try(:balance_credit_additions).present?
    if balance_removal
      balance_removal.calculate_removal_amount
    else
      employee_balance.calculate_removal_amount
    end
  end

  def update_next_employee_balances
    balance_to_update = find_first_balance_for_update
    return if only_in_balance_period?(balance_to_update) || options[:skip_update]
    PrepareEmployeeBalancesToUpdate.new(balance_to_update).call
    UpdateBalanceJob.perform_later(balance_to_update.id)
  end

  def only_in_balance_period?(balance_to_update)
    balance_to_update.last_in_category? || balance_removal.try(:last_in_category?) &&
      Employee::Balance.where(effective_at:
        balance_to_update.effective_at...balance_removal.effective_at).count == 1
  end

  def balancer_removal?
    balance_removal || employee_balance.balance_credit_additions.present?
  end

  def counter_addition?
    employee_balance.policy_credit_addition && employee_balance.time_off_policy.counter?
  end

  def balance_is_not_removal_and_has_validity_date?
    validity_date.present? && @employee_balance.balance_credit_additions.empty?
  end

  def find_first_balance_for_update
    return employee_balance unless employee_balance.time_off_id.present?
    Employee::Balance
      .employee_balances(employee.id, category.id)
      .between(employee_balance.time_off.start_time, employee_balance.time_off.end_time)
      .order(:effective_at)
      .first
  end
end

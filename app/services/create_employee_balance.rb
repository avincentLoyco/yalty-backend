class CreateEmployeeBalance
  attr_reader :category, :employee, :params, :employee_balance, :time_off_policy

  def initialize(category, employee, policy, params)
    @category = category
    @employee = employee
    @params = params
    @time_off_policy = policy
    @employee_balance = nil
  end

  def call
    ActiveRecord::Base.transaction do
      find_or_build_employee_balance
      find_policy unless time_off_policy
      update_balance_attributes if time_off_policy

      save!
    end
  end

  def find_or_build_employee_balance
    @employee_balance = employee.employee_balances.where(id: params[:id]).first_or_initialize
  end

  def find_policy
    @time_off_policy = employee.active_policy(category)
  end

  def update_balance_attributes

  end

  def calculated_balance

  end

  def balance_params
    {
      amount: params[:amount],
      balance: calculated_balance,
      time_off_policy: time_off_policy
    }
  end

  def save!

  end
end

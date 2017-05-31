namespace :db do
  namespace :cleanup do
    task create_missing_balances_and_policies_for_time_offs: [:environment] do
      time_offs = TimeOff.includes(:employee_balance).where('employee_balances.id IS NULL')
                         .references(:employee_balances)

      time_offs.find_each do |time_off|
        category, employee, account, options = setup_params(time_off)
        create_or_find_employeee_policy(employee, category)

        CreateEmployeeBalance.new(category.id, employee.id, account.id, options).call
      end
    end

    def setup_params(time_off)
      [
        time_off.time_off_category,
        time_off.employee,
        time_off.employee.account,
        time_off_id: time_off.id, amount: time_off.balance
      ]
    end

    def create_or_find_employeee_policy(employee, category)
      return if employee.active_policy_in_category_at_date(category.id, Time.zone.now).present?
      policy = create_time_off_policy(category)
      create_employee_time_off_policy(employee, policy)
    end

    def create_time_off_policy(category)
      TimeOffPolicy.create!(time_off_policy_params(category))
    end

    def create_employee_time_off_policy(employee, policy)
      EmployeeTimeOffPolicy.create!(employee: employee, time_off_policy: policy)
    end

    def time_off_policy_params(category)
      { start_day: 1, start_month: 1, time_off_category: category, name: 'default' }
        .merge(policy_amount_and_type(category))
    end

    def policy_amount_and_type(category)
      if category.name == 'vacancy'
        { policy_type: 'balancer', amount: 28_800 }
      else
        { policy_type: 'counter', amount: nil }
      end
    end
  end
end

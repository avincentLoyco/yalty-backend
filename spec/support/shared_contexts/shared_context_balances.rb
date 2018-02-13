RSpec.shared_context 'shared_context_balances' do |settings|
  let!(:category) { create(:time_off_category, account: account) }
  let(:policy) do
    create(:time_off_policy,
      time_off_category: category,
      policy_type: settings[:type],
      end_month: settings[:end_month],
      end_day: settings[:end_day],
      years_to_effect: settings[:years_to_effect],
      amount: settings.fetch(:policy_amount, 0)
    )
  end

  let!(:employee_time_off_policy) do
    create(:employee_time_off_policy,
      employee: employee,
      time_off_policy: policy,
      effective_at: Date.new(2013,1,1)
    )
  end

  # balances in previous policy period
  let(:periods) { EmployeePolicyPeriod.new(employee, category.id) }
  let(:previous) { periods.previous_policy_period }
  let(:current) { periods.current_policy_period }

  if settings[:type] == 'balancer'
    if settings[:end_month] && settings[:end_day]
      let!(:previous_add) do
        create(:employee_balance_manual,
          resource_amount: 1000, effective_at: previous.first, employee: employee,
          time_off_category: category,
          validity_date: previous.last + Employee::Balance::REMOVAL_OFFSET
        )
      end

      let!(:previous_balance) do
        create(:employee_balance_manual, :with_time_off,
          effective_at: previous.first + 3.months, manual_amount: -100,
          employee: employee, time_off_category: category
        )
      end

      let!(:previous_removal) do
        create(:employee_balance_manual,
          resource_amount: -900, employee: employee, time_off_category: category,
          balance_credit_additions: [previous_add], balance_type: 'removal',
          effective_at: previous.last + Employee::Balance::REMOVAL_OFFSET
        )
      end

    else
      let!(:previous_add) do
        create(:employee_balance_manual,
          resource_amount: 1000, effective_at: previous.first + Employee::Balance::ADDITION_OFFSET,
          employee: employee, time_off_category: category
        )
      end

      let!(:previous_balance) do
        create(:employee_balance_manual,
          resource_amount: -900, employee: employee, time_off_category: category,
          effective_at: previous.last + Employee::Balance::END_OF_PERIOD_OFFSET,
          balance_type: 'end_of_period'
        )
      end
    end

  else
    let!(:previous_balance) do
      create(:employee_balance_manual,
        effective_at: previous.first + Employee::Balance::END_OF_PERIOD_OFFSET, resource_amount: -1000,
        employee: employee, time_off_category: category, balance_type: 'end_of_period'
      )
    end

    let!(:previous_removal) do
      create(:employee_balance_manual,
        effective_at: previous.last + Employee::Balance::END_OF_PERIOD_OFFSET,
        resource_amount: -500, employee: employee,
        time_off_category: category, balance_type: 'end_of_period'
      )
    end
  end

  # balances in current policy period
  if settings[:end_month] && settings[:end_day] && settings[:type] == 'balancer'
    let!(:balance_add) do
      create(:employee_balance_manual,
        resource_amount: 1000, employee: employee, time_off_category: category,
        effective_at: current.first + Employee::Balance::ADDITION_OFFSET,
        validity_date: current.last + Employee::Balance::REMOVAL_OFFSET, balance_type: 'addition'
      )
    end
  else
    if settings[:type] == 'counter'
      let!(:balance_add) do
        create(:employee_balance_manual,
          resource_amount: 1500, employee: employee, time_off_category: category,
          effective_at: current.first + Employee::Balance::ADDITION_OFFSET,
          balance_type: 'addition'
        )
      end
    else
      let!(:balance_add) do
        create(:employee_balance_manual,
          resource_amount: 1000, employee: employee, time_off_category: category,
          effective_at: current.first + Employee::Balance::ADDITION_OFFSET,
          balance_type: 'addition'
        )
      end
    end
  end

  let!(:balance) do
    create(:employee_balance_manual, :with_time_off,
      resource_amount: -500, employee: employee, time_off_category: category,
      effective_at: current.last
    )
  end
end

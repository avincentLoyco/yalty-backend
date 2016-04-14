RSpec.shared_context 'shared_context_balances' do |settings|
  let!(:category) { create(:time_off_category, account: account) }
  let(:policy_amount) { 10000 if settings[:type] == "balancer" }
  let(:policy) do
    create(:time_off_policy,
      time_off_category: category,
      policy_type: settings[:type],
      end_month: settings[:end_month],
      end_day: settings[:end_day],
      years_to_effect: settings[:years_to_effect],
      amount: policy_amount
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
  let(:periods) { PolicyPeriod.new(employee, category.id) }
  let(:previous) { periods.previous_policy_period }
  let(:current) { periods.current_policy_period }

  if settings[:type] == 'balancer'
    if settings[:end_month] && settings[:end_day]
      let!(:previous_add) do
        create(:employee_balance,
          amount: 1000, effective_at: previous.first, employee: employee,
          time_off_category: category, validity_date: previous.last
        )
      end

      let!(:previous_balance) do
        create(:employee_balance,
          effective_at: previous.first + 3.months, amount: -100,
          employee: employee, time_off_category: category
        )
      end

      let!(:previous_removal) do
        create(:employee_balance,
          policy_credit_removal: true, amount: -900, employee: employee,
          time_off_category: category, balance_credit_addition: previous_add
        )
      end

    else
      let!(:previous_add) do
        create(:employee_balance,
          amount: 1000, effective_at: previous.first,
          employee: employee, time_off_category: category
        )
      end

      let!(:previous_balance) do
        create(:employee_balance,
          amount: -900, employee: employee, time_off_category: category,
          effective_at: previous.last
        )
      end
    end

  else
    let!(:previous_balance) do
      create(:employee_balance,
        effective_at: previous.first + 9.month, amount: -1000,
        employee: employee, time_off_category: category
      )
    end

    let!(:previous_removal) do
      create(:employee_balance,
        effective_at: previous.last, amount: -500, employee: employee,
        time_off_category: category
      )
    end
  end

  # balances in current policy period

  if settings[:end_month] && settings[:end_day] && settings[:type] == 'balancer'
    let!(:balance_add) do
      create(:employee_balance,
        amount: 1000, employee: employee, time_off_category: category,
        effective_at: current.last - 1.month, validity_date: current.last
      )
    end
  else
    if settings[:type] == 'counter'
      let!(:balance_add) do
        create(:employee_balance,
          amount: 1500, employee: employee, time_off_category: category,
          effective_at: current.last - 1.month, policy_credit_addition: true
        )
      end
    else
      let!(:balance_add) do
        create(:employee_balance,
          amount: 1000, employee: employee, time_off_category: category,
          effective_at: current.last - 1.month, policy_credit_addition: true
        )
      end
    end
  end

  let!(:balance) do
    create(:employee_balance,
      amount: -500, employee: employee, time_off_category: category,
      effective_at: current.last - 1.week
    )
  end
end

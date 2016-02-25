RSpec.shared_context 'shared_context_balances' do |settings|
  let!(:category) { create(:time_off_category, account: account) }
  let(:policy) do
    create(:time_off_policy,
      time_off_category: category,
      policy_type: settings[:type],
      end_month: settings[:end_month],
      end_day: settings[:end_day],
      years_to_effect: settings[:years_to_effect]
    )
  end
  let!(:employee_time_off_policy) do
    create(:employee_time_off_policy, employee: employee, time_off_policy: policy)
  end

  # balances in previous policy period

  let(:previous) { policy.previous_period }
  let(:current) { policy.current_period }

  if settings[:type] == 'balancer'
    if settings[:end_month] && settings[:end_day]
      let!(:previous_add) do
        create(:employee_balance,
          amount: 1000, effective_at: previous.first, time_off_policy: policy, employee: employee,
          time_off_category: category, validity_date: previous.last
        )
      end

      let!(:previous_balance) do
        create(:employee_balance,
          effective_at: previous.last - 1.week, amount: -100, time_off_policy: policy,
          employee: employee, time_off_category: category
        )
      end

      let!(:previous_removal) do
        create(:employee_balance,
          policy_credit_removal: true, amount: -900, time_off_policy: policy, employee: employee,
          time_off_category: category, balance_credit_addition: previous_add
        )
      end

    else
      let!(:previous_add) do
        create(:employee_balance,
          amount: 1000, effective_at: previous.first, time_off_policy: policy,
          employee: employee, time_off_category: category
        )
      end

      let!(:previous_balance) do
        create(:employee_balance,
          amount: -900, time_off_policy: policy, employee: employee, time_off_category: category,
          effective_at: previous.last
        )
      end
    end

  else
    let!(:previous_balance) do
      create(:employee_balance,
        effective_at: previous.first + 1.month, amount: -1000, time_off_policy: policy,
        employee: employee, time_off_category: category
      )
    end

    let!(:previous_removal) do
      create(:employee_balance,
        effective_at: previous.last, policy_credit_removal: true, amount: 1000,
        time_off_policy: policy, employee: employee, time_off_category: category
      )
    end
  end

  # balances in current policy period

  if settings[:end_month] && settings[:end_day] && settings[:type] == 'balancer'
    let!(:balance_add) do
      create(:employee_balance,
        amount: 1000, time_off_policy: policy, employee: employee, time_off_category: category,
        effective_at: current.last - 1.month, validity_date: current.last
      )
    end
  else
    let!(:balance_add) do
      create(:employee_balance,
        amount: 1000, time_off_policy: policy, employee: employee, time_off_category: category,
        effective_at: current.last - 1.month
      )
    end
  end

  let!(:balance) do
    create(:employee_balance,
      amount: -500, time_off_policy: policy, employee: employee, time_off_category: category,
      effective_at: current.last - 1.week
    )
  end
end

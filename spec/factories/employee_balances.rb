FactoryGirl.define do
  factory :employee_balance, :class => 'Employee::Balance' do
    employee
    time_off_category { create(:time_off_category, account: employee.account) }
    resource_amount { Faker::Number.number(2) }
    policy_credit_addition { true }
    after(:build) do |employee_balance|
      effective_at = employee_balance.effective_at ? employee_balance.effective_at : Time.zone.now
      etop =
        employee_balance
        .employee
        .active_policy_in_category_at_date(employee_balance.time_off_category_id, effective_at)
      if etop.blank? && employee_balance.time_off_id.blank?
        employee_balance.effective_at = employee_balance.employee.hired_date if employee_balance.effective_at.nil?
        policy = create(:time_off_policy,
          time_off_category: employee_balance.time_off_category,
          years_to_effect: 1
        )
        employee_policy = create(:employee_time_off_policy,
          time_off_policy: policy,
          employee: employee_balance.employee,
          effective_at: employee_balance.effective_at
        )
        employee_balance.effective_at = employee_policy.effective_at
      elsif employee_balance.time_off_id.blank?
        top = etop.time_off_policy
        last_balance_in_category =
          employee_balance
          .employee
          .employee_balances
          .where(time_off_category_id: top.time_off_category_id, policy_credit_addition: true)
          .order('effective_at').last
        if last_balance_in_category.present?
          year = last_balance_in_category.effective_at.year + 1
          balance_date = Date.new(year, top.start_month, top.start_day)
        else
          balance_date = etop.effective_at
        end
        employee_balance.effective_at = balance_date
      end
    end

    trait :processing do
      being_processed true
    end

    trait :with_time_off do
      policy_credit_addition { false }
      after(:build) do |employee_balance|
        time_off =
          create(:time_off, :without_balance, employee: employee_balance.employee, time_off_category: employee_balance.time_off_category)
        employee_balance.time_off = time_off
        employee_balance.effective_at = time_off.end_time.to_date
      end
    end

    trait :with_balance_credit_addition do
      after(:build) do |employee_balance|
        balance_addition = build(:employee_balance,
          balance_credit_removal: employee_balance,
          employee: employee_balance.employee,
          time_off_category: employee_balance.time_off_category,
          effective_at: Time.now - 2.weeks,
          validity_date: Time.now - 1.week
        )

        employee_balance.balance_credit_additions << balance_addition
      end
    end

    trait :with_employee_time_off_policy do
      employee_time_off_policy { create(:employee_time_off_policy, employee: employee) }
    end
  end

  factory :employee_balance_manual, :class => 'Employee::Balance' do
    employee
    time_off_category { create(:time_off_category, account: employee.account) }
    resource_amount { Faker::Number.number(2) }
    effective_at { nil }

    trait :processing do
      being_processed true
    end

    trait :with_time_off do
      after(:build) do |employee_balance|
        end_time = employee_balance.effective_at || 1.month.since
        start_time = end_time - 1.day
        time_off =
          create(:time_off, :without_balance, employee: employee_balance.employee,
            time_off_category: employee_balance.time_off_category, start_time: start_time,
            end_time: end_time)
        employee_balance.time_off = time_off
      end
    end
  end
end

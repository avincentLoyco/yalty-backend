FactoryGirl.define do
  factory :employee_balance, :class => 'Employee::Balance' do
    employee
    time_off_category { create(:time_off_category, account: employee.account) }
    amount { Faker::Number.number(5) }

    after(:build) do |employee_balance|
      if employee_balance.employee.active_policy_in_category_at_date(employee_balance.time_off_category_id).blank?
        policy = create(:time_off_policy,
          time_off_category: employee_balance.time_off_category,
          years_to_effect: 5
        )
        employee_policy = create(:employee_time_off_policy,
          time_off_policy: policy,
          employee: employee_balance.employee,
          effective_at: Date.today - 7.years
        )
        employee_balance.employee.employee_time_off_policies << employee_policy
      end
    end

    trait :processing do
      being_processed true
    end

    trait :with_time_off do
      time_off { create(:time_off, time_off_category: time_off_category) }
    end
  end
end

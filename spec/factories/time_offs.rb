FactoryGirl.define do
  factory :time_off do
    start_time Time.now
    end_time Time.now + 1.month
    employee
    time_off_category
    employee_balance { nil }

    after(:build) do |time_off|
      if time_off.employee.employee_time_off_policies.any?
        time_off.time_off_category = time_off.employee.employee_time_off_policies.first
          .time_off_category
      end

      if time_off.employee_balance.blank?
        time_off.employee_balance = build(:employee_balance,
          employee: time_off.employee,
          time_off_category: time_off.time_off_category,
          effective_at: time_off.end_time,
          time_off: time_off,
          resource_amount: time_off.balance
        )
      end
    end

    trait :processed do
      being_processed true
    end

    trait :without_balance do
      after(:build) do |time_off|
        time_off.employee_balance.destroy!
      end
    end
  end

  factory :no_category_assigned_time_off, class: TimeOff do
    start_time Time.now
    end_time Time.now + 1.month
    employee
    time_off_category { FactoryGirl.build(:time_off_category) }
    employee_balance { FactoryGirl.build(:employee_balance, employee: employee, time_off_category: time_off_category) }

    after(:build) do |time_off|
      if time_off.employee.employee_time_off_policies.present? && !time_off.valid?
        time_off.time_off_category = time_off.employee.employee_time_off_policies.first
          .time_off_policy.time_off_category
      end
    end
  end
end

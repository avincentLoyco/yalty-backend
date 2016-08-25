FactoryGirl.define do
  factory :employee_time_off_policy do
    employee
    time_off_policy
    effective_at { Time.zone.today - 1.year }

    trait :with_employee_balance do
      after(:create) do |policy|
        amount = policy.time_off_policy.counter? ? 0 : policy.time_off_policy.amount
        time_off_policy = policy.time_off_policy
        amount = time_off_policy.counter? ? 0 : time_off_policy.amount
        create(:employee_balance,
          resource_amount: amount,
          employee: policy.employee,
          time_off_category: policy.time_off_policy.time_off_category,
          policy_credit_addition: true,
          employee_time_off_policy: policy,
          effective_at: policy.effective_at
        )
      end
    end
  end
end

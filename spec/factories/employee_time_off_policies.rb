FactoryGirl.define do
  factory :employee_time_off_policy do
    employee
    time_off_policy
    effective_at { Time.zone.today }

    trait :with_employee_balance do
      after(:build) do |policy|
        time_off_policy = policy.time_off_policy
        amount = time_off_policy.counter? ? 0 : time_off_policy.amount
        create(:employee_balance,
          amount: amount,
          employee: policy.employee,
          time_off_policy: time_off_policy,
          time_off_category: time_off_policy.time_off_category,
          policy_credit_addition: true
        )
      end
    end
  end
end

FactoryGirl.define do
  factory :employee_time_off_policy do
    employee
    time_off_policy
    effective_at { Time.zone.today - 1.year }

    after(:build) do |etop|
      reset_policy =
        etop.employee .employee_time_off_policies .with_reset .find_by(effective_at: etop.effective_at, time_off_category_id: etop.time_off_policy.time_off_category_id)
      reset_policy.destroy if reset_policy.present?
    end

    trait :with_employee_balance do
      after(:create) do |policy|
        amount = policy.time_off_policy.counter? ? 0 : policy.time_off_policy.amount
        time_off_policy = policy.time_off_policy
        amount = time_off_policy.counter? ? 0 : time_off_policy.amount
        create(:employee_balance_manual,
          resource_amount: amount,
          employee: policy.employee,
          time_off_category: policy.time_off_policy.time_off_category,
          policy_credit_addition: true,
          effective_at: policy.effective_at + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
          validity_date: RelatedPolicyPeriod.new(policy).validity_date_for(policy.effective_at)
        )
      end
    end
  end
end

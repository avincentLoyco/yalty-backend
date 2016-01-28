FactoryGirl.define do
  factory :time_off do
    association :employee, :with_policy
    start_time Time.now
    end_time Time.now + 1.month

    after(:build) do |time_off|
      time_off.time_off_category = time_off.employee.employee_time_off_policies
        .first.time_off_policy.time_off_category
    end
  end
end

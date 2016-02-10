FactoryGirl.define do
  factory :time_off do
    start_time Time.now
    end_time Time.now + 1.month
    association :employee, factory: [:employee, :with_policy]

    after(:build) do |time_off|
      if time_off.employee.employee_time_off_policies.present?
        time_off.time_off_category = time_off.employee.employee_time_off_policies.first
          .time_off_policy.time_off_category
      end
    end
  end
end

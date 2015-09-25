FactoryGirl.define do
  factory :employee do
    account

    trait :with_attributes do
      after(:build) do |employee, evaluator|
        event = FactoryGirl.build(:employee_event, employee: employee)
        event.employee_attribute_versions << FactoryGirl.build_list(
          :employee_attribute_version, 2,
          employee: employee,
          event: event
        )

        employee.events << event
      end
    end
  end
end

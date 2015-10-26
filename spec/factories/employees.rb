FactoryGirl.define do
  factory :employee do
    account

    trait :with_attributes do
      transient do
        employee_attributes { Hash.new }
      end

      after(:build) do |employee, evaluator|
        event = FactoryGirl.build(:employee_event, employee: employee)

        if evaluator.employee_attributes.empty?
          event.employee_attribute_versions << FactoryGirl.build_list(
              :employee_attribute_version, 2,
              employee: employee,
              event: event
            )
        else
          evaluator.employee_attributes.each do |name, value|
            attribute = FactoryGirl.build(
              :employee_attribute_version,
              attribute_name: name,
              employee: employee,
              event: event
            )
            attribute.value = value

            event.employee_attribute_versions << attribute
          end
        end

        employee.events << event
      end
    end
  end
end

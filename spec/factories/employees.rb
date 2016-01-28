FactoryGirl.define do
  factory :employee do
    account
    working_place { create(:working_place, account: account) }

    trait :with_policy do
      transient do
        employee_time_off_policies { Hash.new }
      end

      after(:build) do |employee|
        policy = create(:employee_time_off_policy)
        employee.employee_time_off_policies << policy
      end
    end

    trait :with_attributes do
      transient do
        event { Hash.new }
        employee_attributes { Hash.new }
      end

      after(:build) do |employee, evaluator|
        event = FactoryGirl.build(:employee_event, evaluator.event.merge(employee: employee))

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

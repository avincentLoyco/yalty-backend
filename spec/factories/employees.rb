FactoryGirl.define do
  factory :employee do
    account
    working_place { create(:working_place, account: account) }
    created_at { Time.now - 10.years }

    trait :with_policy do
      transient do
        employee_time_off_policies { Hash.new }
      end

      after(:build) do |employee|
        policy = create(:employee_time_off_policy)
        employee.employee_time_off_policies << policy
      end
    end

    trait :with_time_offs do
      transient do
        employee_time_off_policies { Hash.new }
        time_offs { Hash.new }
      end

      after(:build) do |employee|
        first_policy = create(:employee_time_off_policy)
        second_policy = create(:employee_time_off_policy)
        employee.employee_time_off_policies << [first_policy, second_policy]
      end

      after(:create) do |employee|
        first_policy = employee.employee_time_off_policies.first.time_off_policy
        second_policy = employee.employee_time_off_policies.last.time_off_policy

        first_balance = create(:employee_balance,
          employee: employee,
          time_off_category: first_policy.time_off_category
        )
        second_balance = create(:employee_balance,
          employee: employee,
          time_off_category: second_policy.time_off_category
        )

        third_balance = create(:employee_balance,
          employee: employee,
          time_off_category: second_policy.time_off_category
        )

        first_time_off = create(:no_category_assigned_time_off,
          time_off_category: first_policy.time_off_category,
          employee: employee,
          employee_balance: first_balance
        )

        second_time_off = create(:no_category_assigned_time_off,
          time_off_category: second_policy.time_off_category,
          employee: employee,
          start_time: Date.today,
          employee_balance: second_balance
        )

        third_time_off = create(:no_category_assigned_time_off,
          time_off_category: second_policy.time_off_category,
          employee: employee,
          start_time: Date.today + 1.day,
          employee_balance: third_balance
        )
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

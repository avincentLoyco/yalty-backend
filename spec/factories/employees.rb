FactoryGirl.define do
  factory :employee do
    account

    after(:build) do |employee|
      if employee.employee_working_places.empty?
        working_place = build(:working_place, account: employee.account)
        employee_working_place = build(
          :employee_working_place,
          employee: employee,
          working_place: working_place
        )
        employee.employee_working_places << employee_working_place
      end

      if employee.events.empty?
        hired_event = build(:employee_event,
          event_type: 'hired',
          employee: employee,
          effective_at: Time.zone.now - 6.years
        )
        employee.events << hired_event
      end
    end

    trait :with_presence_policy do

      transient do
        presence_policy nil
      end

      after(:create) do |employee, evaluator|
        attributes =
          { employee: employee , effective_at: employee.created_at}
          .merge( evaluator.presence_policy.present? ? { presence_policy: evaluator.presence_policy } : {} )
        create(:employee_presence_policy, attributes)
      end
    end

    trait :with_time_off_policy do
      transient do
        employee_time_off_policies { Hash.new }
      end

      after(:build) do |employee|
        policy = build(:employee_time_off_policy)
        employee.employee_time_off_policies << policy
        policy.save!
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

        create(:no_category_assigned_time_off,
          time_off_category: first_policy.time_off_category,
          employee: employee,
          employee_balance: first_balance
        )

        create(:no_category_assigned_time_off,
          time_off_category: second_policy.time_off_category,
          employee: employee,
          start_time: Date.today,
          employee_balance: second_balance
        )

        create(:no_category_assigned_time_off,
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
        if employee.events.blank?
          event = FactoryGirl.build(:employee_event, evaluator.event.merge(employee: employee))
        else
          event = employee.events.first
        end

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

FactoryGirl.define do
  factory :employee do
    id { SecureRandom.uuid }
    account { create(:account) }

    transient do
      hired_at { 6.years.ago }
      contract_end_at { nil }
      role { nil }
    end

    after(:build) do |employee, evaluator|
      unless evaluator.role.nil?
        create(:account_user, employee: employee, account: employee.account, role: evaluator.role)
      end

      if employee.events.empty?
        hired_at = if employee.employee_working_places.empty?
                     evaluator.hired_at
                   else
                     employee.employee_working_places.first.effective_at
                   end

        hired_event = build(:employee_event,
          event_type: "hired",
          employee: employee,
          effective_at: hired_at
        )
        employee.events << hired_event

        if evaluator.contract_end_at
          contract_end_event = build(:employee_event,
            event_type: "contract_end",
            employee: employee,
            effective_at: evaluator.contract_end_at
          )
          employee.events << contract_end_event
        end
      end
    end

    trait :hired_now do
      after(:build) do |employee|
        employee.events.delete_all
        hired_event = build(:employee_event,
          event_type: "hired",
          employee: employee,
          effective_at: Time.zone.now
        )
        employee.events << hired_event
      end
    end

    factory :employee_hired_now, traits: [:hired_now]

    trait :with_working_place do
      after(:build) do |employee|
        effective_at = Time.zone.now - 6.years
        working_place = build(:working_place, account: employee.account)
        date = employee.events.empty? ? effective_at : employee.events.first.effective_at
        employee_working_place = build(
          :employee_working_place,
          employee: employee,
          working_place: working_place,
          effective_at: date
        )
        employee.employee_working_places << employee_working_place
      end
    end

    factory :employee_with_working_place, traits: [:with_working_place]

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
        employee.valid?
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
          start_time: Date.today,
          end_time: Date.today + 2.days,
          employee_balance: first_balance
        )

        create(:no_category_assigned_time_off,
          time_off_category: second_policy.time_off_category,
          employee: employee,
          start_time: Date.today + 2.days,
          end_time: Date.today + 4.days,
          employee_balance: second_balance
        )

        create(:no_category_assigned_time_off,
          time_off_category: second_policy.time_off_category,
          employee: employee,
          start_time: Date.today + 4.days,
          end_time: Date.today + 6.days,
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

            if attribute.data.attribute_type.eql?("File") && value
              attribute.data.id = value[:value]
              attribute.data.size = 1000
              attribute.data.file_type = "image/jpeg"
              attribute.data.original_sha = "123456781234"
            else
              attribute.value = value
            end
            event.employee_attribute_versions << attribute
          end
        end
        employee.events << event if employee.events.blank?
        employee.valid?
      end
    end
  end
end

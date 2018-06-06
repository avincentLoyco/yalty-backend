FactoryGirl.define do
  factory :time_off do
    start_time Time.now
    end_time Time.now + 1.month
    employee
    time_off_category { FactoryGirl.create(:time_off_category, account: employee.account) }
    employee_balance { nil }

    after(:build) do |time_off|
      unless time_off.employee.active_policy_in_category_at_date(time_off.time_off_category_id, time_off.start_time)
        if time_off.employee.employee_time_off_policies.any?
          time_off.time_off_category = time_off.employee.employee_time_off_policies.first
            .time_off_category
        end
      end

      etop = time_off
        .employee
        .active_policy_in_category_at_date(time_off.time_off_category_id, time_off.start_time)
      if etop.blank?
        create(:employee_time_off_policy,
          time_off_policy: create(:time_off_policy, time_off_category: time_off.time_off_category),
          employee: time_off.employee,
          effective_at: time_off.start_time
        )
      end
    end

    trait :processed do
      being_processed true
    end
  end

  factory :no_category_assigned_time_off, class: TimeOff do
    start_time Time.now
    end_time Time.now + 1.month
    employee
    time_off_category { FactoryGirl.build(:time_off_category) }
    employee_balance { FactoryGirl.build(:employee_balance, employee: employee, time_off_category: time_off_category) }

    after(:build) do |time_off|
      if time_off.employee.employee_time_off_policies.present? && !time_off.valid?
        time_off.time_off_category = time_off.employee.employee_time_off_policies.first
          .time_off_policy.time_off_category
      end
    end
  end
end

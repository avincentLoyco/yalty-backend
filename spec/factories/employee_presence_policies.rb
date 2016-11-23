FactoryGirl.define do
  factory :employee_presence_policy do
    employee
    presence_policy { create(:presence_policy, :with_presence_day, account: employee.account) }
    effective_at { Faker::Date.between(Date.today, Date.today + 5.days) }
    order_of_start_day 1

    trait :with_time_entries do
      presence_policy { create(:presence_policy, :with_time_entries, account: employee.account) }
    end
  end
end

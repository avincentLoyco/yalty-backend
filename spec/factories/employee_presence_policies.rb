FactoryGirl.define do
  factory :employee_presence_policy do
    employee
    presence_policy
    effective_at { Faker::Date.between( Date.today, Date.today+5.days) }
    order_of_start_day 1
  end
end

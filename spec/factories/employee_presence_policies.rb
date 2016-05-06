FactoryGirl.define do
  factory :employee_presence_policy do
    employee
    presence_policy
    effective_at { Time.zone.today - 1.year }
    start_day_order 1
  end
end

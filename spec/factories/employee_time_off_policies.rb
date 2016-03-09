FactoryGirl.define do
  factory :employee_time_off_policy do
    employee
    time_off_policy
    effective_at { Time.zone.today }
  end
end

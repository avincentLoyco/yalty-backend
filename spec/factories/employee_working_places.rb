FactoryGirl.define do
  factory :employee_working_place do
    employee
    working_place { create(:working_place, account: employee.account) }
    effective_at { Faker::Date.between(2.days.ago, Date.today) }
  end
end

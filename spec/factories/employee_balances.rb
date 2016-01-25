FactoryGirl.define do
  factory :employee_balance, :class => 'Employee::Balance' do
    employee
    time_off_category { create(:time_off_category, account: employee.account) }
    time_off { create(:time_off, time_off_category: time_off_category) }
    time_off_policy { create(:time_off_policy, time_off_category: time_off_category) }
    amount { Faker::Number.number(5) }

    trait :processing do
      beeing_processed true
    end
  end
end

FactoryGirl.define do
  factory :employee_balance, :class => 'Employee::Balance' do
    employee
    time_off_category { create(:time_off_category, account: employee.account) }
    amount { Faker::Number.number(5) }

    trait :processing do
      being_processed true
    end

    trait :with_time_off do
      time_off { create(:time_off, time_off_category: time_off_category) }
    end
  end
end

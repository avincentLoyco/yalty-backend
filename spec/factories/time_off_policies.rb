FactoryGirl.define do
  factory :time_off_policy do
    time_off_category
    amount { Faker::Number.number(4) }
    start_day Time.now.day
    start_month Time.now.month
    end_day (Time.now + 1.month).day
    end_month (Time.now + 1.month).month
    policy_type 'balance'
    years_to_effect 0
    years_passed 0

    trait :as_counter do
      policy_type 'counter'
    end

    trait :longer_than_year do
      years_to_effect 1
    end
  end
end

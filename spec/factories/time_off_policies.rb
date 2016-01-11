FactoryGirl.define do
  factory :time_off_policy do
    time_off_category
    amount { Faker::Number.number(4) }
    start_time Time.now
    end_time Time.now + 1.month
    policy_type 'balance'

    trait :as_counter do
      policy_type 'counter'
    end
  end
end

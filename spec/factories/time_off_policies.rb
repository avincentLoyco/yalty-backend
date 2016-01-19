FactoryGirl.define do
  factory :time_off_policy do
    time_off_category
    amount { Faker::Number.number(4) }
    start_time '01.01'
    end_time '01.04'
    policy_type 'balance'
    years_to_effect 0

    trait :as_counter do
      policy_type 'counter'
    end

    trait :longer_than_year do
      years_to_effect 1
    end
  end
end

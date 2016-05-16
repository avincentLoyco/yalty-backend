FactoryGirl.define do
  factory :time_off_policy do
    time_off_category
    name { Faker::Lorem.word }
    amount { Faker::Number.number(4) }
    start_day 1
    start_month 1
    policy_type 'balancer'
    years_to_effect 0

    trait :as_counter do
      policy_type 'counter'
      amount nil
    end

    trait :with_end_date do
      end_day 1
      end_month 4
    end
  end
end

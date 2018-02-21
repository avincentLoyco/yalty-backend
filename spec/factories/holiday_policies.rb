FactoryGirl.define do
  factory :holiday_policy do
    account
    country "pl"

    trait :with_region do
      country "ch"
      region "zh"
    end
  end
end

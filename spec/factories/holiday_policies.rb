FactoryGirl.define do
  factory :holiday_policy do
    account
    name { Faker::Lorem.word }

    trait :with_country do
      country 'pl'
    end

    trait :with_region do
      country 'ch'
      region 'zh'
    end
  end
end

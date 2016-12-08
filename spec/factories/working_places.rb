FactoryGirl.define do
  factory :working_place do
    account
    name { Faker::Lorem.word }

    trait :with_address do
      country 'Switzerland'
      city 'Zurich'
    end
  end
end

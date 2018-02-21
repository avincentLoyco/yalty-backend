FactoryGirl.define do
  factory :working_place do
    account
    name { Faker::Lorem.word }

    trait :with_address do
      city "Zurich"
      country_code "CH"
    end
  end
end

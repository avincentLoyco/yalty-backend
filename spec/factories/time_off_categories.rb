FactoryGirl.define do
  factory :time_off_category do
    account
    name { Faker::Lorem.characters(10) }

    trait :system do
      system true
    end
  end
end

FactoryGirl.define do
  factory :time_off_category do
    account
    name { Faker::Lorem.word }

    trait :system do
      system true
    end
  end
end

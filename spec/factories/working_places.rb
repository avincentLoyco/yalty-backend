FactoryGirl.define do
  factory :working_place do
    account
    name { Faker::Lorem.word }
    country 'Switzerland'
    city 'Zurich'
  end
end

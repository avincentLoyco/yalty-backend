FactoryGirl.define do
  factory :working_place do
    account
    name { Faker::Lorem.word }
  end
end

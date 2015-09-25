FactoryGirl.define do
  factory :holiday_policy do
    account
    name { Faker::Lorem.word }
  end
end

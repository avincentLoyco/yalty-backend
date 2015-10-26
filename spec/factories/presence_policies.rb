FactoryGirl.define do
  factory :presence_policy do
    account
    name { Faker::Lorem.word }
  end
end

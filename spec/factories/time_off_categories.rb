FactoryGirl.define do
  factory :time_off_category do
    account
    name { Faker::Lorem.word }
  end
end

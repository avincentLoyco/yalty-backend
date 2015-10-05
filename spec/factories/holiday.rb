FactoryGirl.define do
  factory :holiday do
    holiday_policy
    name { Faker::Lorem.word }
    date { Faker::Date.forward }
  end
end

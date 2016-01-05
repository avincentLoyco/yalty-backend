FactoryGirl.define do
  factory :presence_day do
    presence_policy
    order { Faker::Number.number(4) }
  end
end

FactoryGirl.define do
  factory :presence_day do
    presence_policy
    order { Faker::Number.number(2) }
    hours { Faker::Number.between(1, 8) }
  end
end

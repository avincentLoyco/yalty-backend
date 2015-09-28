FactoryGirl.define do
  factory :account do
    company_name { Faker::Company.name }

    trait :from_zurich do
      timezone { 'Europe/Zurich' }
    end
  end
end

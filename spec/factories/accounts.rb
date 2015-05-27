FactoryGirl.define do
  factory :account do
    company_name { Faker::Company.name }
  end
end

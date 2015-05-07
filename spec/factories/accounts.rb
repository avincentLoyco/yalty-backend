FactoryGirl.define do
  factory :account do
    subdomain { Faker::Internet.domain_word }
    company_name { Faker::Company.name }
  end
end

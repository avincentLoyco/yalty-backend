FactoryGirl.define do
  factory :account do
    subdomain { Faker::Internet.domain_word }
  end
end

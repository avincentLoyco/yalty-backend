FactoryGirl.define do
  factory :account_user, class: Account::User do
    email { Faker::Internet.email }
    password { Faker::Internet.password(8, 74) }
    account
  end
end

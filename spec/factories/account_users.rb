FactoryGirl.define do
  factory :account_user, class: Account::User do
    email { Faker::Internet.email }
    password { Faker::Internet.password(8, 74) }
    account

    trait :with_reset_password_token do
      reset_password_token { Faker::Lorem.characters(16) }
    end
  end
end

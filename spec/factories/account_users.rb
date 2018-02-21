FactoryGirl.define do
  factory :account_user, class: Account::User do
    email { Faker::Internet.email }
    password { Faker::Internet.password(8, 74) }
    account { create(:account) }
    employee { build(:employee, account: account) }

    trait :with_reset_password_token do
      reset_password_token { Faker::Lorem.characters(16) }
    end

    trait :with_yalty_role do
      email { ENV["YALTY_ACCESS_EMAIL"] }
      role { "yalty" }
      employee { nil }
    end

    after(:create) do |user, evaluator|
      user.account.instance_variable_set(:@recently_created, false)
    end
  end
end

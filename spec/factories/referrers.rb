FactoryGirl.define do
  factory :referrer do
    email { Faker::Internet.email }

    trait :with_token do
      token { SecureRandom.hex(Referrer::TOKEN_LENGTH) }
    end
  end
end

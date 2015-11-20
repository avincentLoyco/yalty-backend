FactoryGirl.define do
  factory :registration_key, class: Account::RegistrationKey do

    trait :with_account do
      account
    end
  end
end

FactoryGirl.define do
  factory :company_event do
    title { Faker::Lorem.sentence }
    effective_at { Date.today }
    comment { Faker::Lorem.sentence }
    account

    trait :with_files do
      files { create_list(:generic_file, 3) }
    end
  end
end

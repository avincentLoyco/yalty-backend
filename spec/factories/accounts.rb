FactoryGirl.define do
  factory :account do
    company_name { Faker::Company.name }

    transient do
      create_presence_policy true
    end

    after(:create) do |account, evaluator|
      if evaluator.create_presence_policy
        default_presence_policy =
          create(:presence_policy, :with_time_entries, occupation_rate: 0.5,
                 standard_day_duration: 9600, default_full_time: true, account: account)

        account.presence_policies << default_presence_policy
      end
    end


    trait :from_zurich do
      timezone { "Europe/Zurich" }
    end

    trait :with_stripe_fields do
      customer_id { SecureRandom.hex }
      subscription_id { SecureRandom.hex }
    end

    trait :with_available_modules do
      available_modules {
        modules = Payments::AvailableModules.new
        modules.add(id: "filevault")
        modules
      }
    end

    trait :with_billing_information do
      company_information {
        {
          company_name: Faker::Company.name,
          address_2: Faker::Name.name,
          city: Faker::Address.city,
          country: Faker::Address.country,
          postalcode: Faker::Address.postcode,
          region: Faker::Address.country_code,
          address_1: "#{Faker::Address.building_number} #{Faker::Address.street_name}",
          phone: Faker::PhoneNumber.phone_number,
        }
      }
      invoice_emails [ Faker::Internet.email, Faker::Internet.email ]
    end
  end
end

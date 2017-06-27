FactoryGirl.define do
  factory :account do
    company_name { Faker::Company.name }

    trait :from_zurich do
      timezone { 'Europe/Zurich' }
    end

    trait :with_stripe_fields do
      customer_id { SecureRandom.hex }
      subscription_id { SecureRandom.hex }
    end

    trait :with_available_modules do
      available_modules {
        modules = Payments::AvailableModules.new
        modules.add(id: 'filevault')
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
          phone: Faker::PhoneNumber.phone_number
        }
      }
      invoice_emails [ Faker::Internet.email, Faker::Internet.email ]
    end
  end
end

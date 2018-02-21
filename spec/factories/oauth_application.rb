FactoryGirl.define do
  factory :oauth_application, aliases: [:oauth_client], class: Doorkeeper::Application do
    name { Faker::Company.name }
    redirect_uri { Faker::Internet.url(Faker::Internet.domain_name, "/") }
    scopes "all_access"
  end
end


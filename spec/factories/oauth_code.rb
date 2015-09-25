FactoryGirl.define do
  factory :oauth_code, class: Doorkeeper::AccessGrant do
    resource_owner_id { FactoryGirl.create(:account_user).id }
    expires_in 600
    association :application, factory: :oauth_application
    redirect_uri { application.redirect_uri }
  end
end

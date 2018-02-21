FactoryGirl.define do
  factory :account_user_token, class: Doorkeeper::AccessToken do
    resource_owner_id { FactoryGirl.create(:account_user).id }
    expires_in 600
    association :application, factory: :oauth_application
    scopes "all_access"
  end
end

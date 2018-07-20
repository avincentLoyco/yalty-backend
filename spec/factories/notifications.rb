FactoryGirl.define do
  factory :notification do
    notification_type "time_off_request"
    seen false
    association :user, factory: :account_user, strategy: :build
  end
end

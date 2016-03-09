FactoryGirl.define do
  factory :working_place_time_off_policy do
    working_place
    time_off_policy
    effective_at { Time.zone.today }
  end
end

FactoryGirl.define do
  factory :presence_policy do
    account
    name { Faker::Lorem.word }

    trait :with_time_entries do
      after(:build) do |presence_policy|
        presence_day_order_one = create(:presence_day, order: 1, presence_policy: presence_policy)
        presence_day_order_four = create(:presence_day, order: 4, presence_policy: presence_policy)

        presence_policy.presence_days << [presence_day_order_four, presence_day_order_one]

        time_entry_one = create(:time_entry,
          presence_day: presence_day_order_one, start_time: '14:00', end_time: '20:00')

        time_entry_two = create(:time_entry,
          presence_day: presence_day_order_four, start_time: '8:00', end_time: '12:00')

        presence_day_order_one.time_entries << [time_entry_one]
        presence_day_order_four.time_entries << [time_entry_two]
      end
    end
  end
end

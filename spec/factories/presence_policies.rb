FactoryGirl.define do
  factory :presence_policy do
    account
    name { Faker::Lorem.word }

    trait :with_presence_day do
      after(:create) do |presence_policy|
        presence_day = create(:presence_day, order: 3, presence_policy: presence_policy)
        presence_policy.presence_days << presence_day
      end
    end

    trait :with_time_entries do
      transient do
        number_of_days 2
        working_days [1, 2]
        hours_per_day 8
      end

      after(:create) do |presence_policy, evaluator|
        hours_per_time_entry = (evaluator.hours_per_day / 2.0) * 3600

        evaluator.number_of_days.times do |order|
          presence_day = create(:presence_day, order: order + 1, presence_policy: presence_policy)

          if evaluator.working_days.include?(presence_day.order)
            presence_day.time_entries << create(:time_entry,
              presence_day: presence_day,
              start_time: Tod::TimeOfDay.new(12) - hours_per_time_entry,
              end_time: '12:00'
            )
            presence_day.time_entries << create(:time_entry,
              presence_day: presence_day,
              start_time: '13:00',
              end_time: Tod::TimeOfDay.new(13) + hours_per_time_entry
            )
          end

          presence_policy.presence_days << presence_day
        end
      end
    end
  end
end

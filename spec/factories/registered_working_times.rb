FactoryGirl.define do
  factory :registered_working_time do
    employee
    date '1/5/2016'
    time_entries do
      [{ start_time: '10:00', end_time: '14:00' }, { start_time: '15:00', end_time: '20:00' }]
    end

    trait :schedule_generated do
      schedule_generated true
    end
  end
end

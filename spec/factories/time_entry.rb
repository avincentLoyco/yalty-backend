 FactoryGirl.define do
  factory :time_entry do
    presence_day
    start_time { "16:00" }
    end_time { "17:00" }
  end
end

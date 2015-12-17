 FactoryGirl.define do
  factory :time_entry do
    presence_day
    start_time { DateTime.now.to_s(:time) }
    end_time { (DateTime.now + 2.hours).to_s(:time) }
  end
end

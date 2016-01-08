FactoryGirl.define do
  factory :time_off do
    employee
    time_off_category
    start_time Time.now
    end_time Time.now + 1.month
  end
end

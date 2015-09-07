FactoryGirl.define do
  factory :employee_event, :class => 'Employee::Event' do
    employee
    effective_at { 1.day.ago.at_beginning_of_day }
    comment 'A comment about event'

    after(:build) do |event, evaluator|
      create_list(:employee_attribute_version, 3, event: event)
    end
  end
end

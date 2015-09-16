FactoryGirl.define do
  factory :employee_event, :class => 'Employee::Event' do
    employee
    account { employee.account }
    effective_at { 1.day.ago.at_beginning_of_day }
    event_type 'default'
    comment 'A comment about event'
  end
end

FactoryGirl.define do
  factory :employee_event, :class => 'Employee::Event' do
    effective_at { 1.day.ago.at_beginning_of_day }
    event_type 'default'
    comment 'A comment about event'

    after(:build) do |employee_event|
      if employee_event.employee.blank?
        employee_event.event_type = 'hired'
        employee = build(:employee, events: [employee_event])
        employee_event.employee = employee
      end

      employee_event.account = employee_event.employee.account
    end
  end
end

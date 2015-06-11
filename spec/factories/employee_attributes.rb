FactoryGirl.define do
  factory :employee_attribute, class: 'Employee::Attribute::Text' do
    name 'test'
    employee
  end
end

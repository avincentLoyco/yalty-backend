FactoryGirl.define do
  factory :employee_attribute, class: 'Employee::Attribute' do
    name 'test'
    employee
  end
end

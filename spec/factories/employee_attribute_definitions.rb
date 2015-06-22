FactoryGirl.define do
  factory :employee_attribute_definition, class: 'Employee::AttributeDefinition' do
    name 'comment'
    label 'Comment'
    attribute_type 'Text'
    account
  end
end

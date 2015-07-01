FactoryGirl.define do
  factory :employee_attribute_definition, class: 'Employee::AttributeDefinition' do
    name 'comment'
    label 'Comment'
    system false
    attribute_type Attribute::Line.attribute_type
    account
  end
end

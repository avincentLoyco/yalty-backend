FactoryGirl.define do
  factory :employee_attribute_definition, class: 'Employee::AttributeDefinition' do
    name {|n| "comment#{n}" }
    label 'Comment'
    system false
    attribute_type Attribute::Line.attribute_type
    account

    trait :multiple do
      multiple true
    end

    trait :pet_multiple do
      multiple true
      name 'pet'
    end
  end
end

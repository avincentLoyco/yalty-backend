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

    trait :system do
      system true
    end

    trait :required do
      validation { { presence: true } }
    end

    trait :required_with_nil_allowed do
      validation { { presence: { allow_nil: true } } }
    end

    trait :valid_country_code do
      validation { { country_code: true } }
    end

    trait :valid_state_code do
      validation { { state_code: true } }
    end
  end
end

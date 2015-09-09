FactoryGirl.define do
  factory :employee_attribute_version, aliases: [:employee_attribute], class: 'Employee::AttributeVersion' do
    employee
    association :event, factory: 'employee_event'

    transient do
      sequence(:attribute_name) {|n| "test#{n}" }
      attribute_type { Attribute::Line.attribute_type }
    end

    after(:build) do |attr, evaluator|
      attr.attribute_name = evaluator.attribute_name

      if attr.attribute_name.nil?
        FactoryGirl.create(:employee_attribute_definition,
          name: evaluator.attribute_name,
          attribute_type: evaluator.attribute_type,
          account: attr.account
        )

        attr.attribute_name = evaluator.attribute_name
      end
    end
  end
end

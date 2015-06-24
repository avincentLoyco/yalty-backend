FactoryGirl.define do
  factory :employee_attribute, class: 'Employee::Attribute::Text' do
    employee

    transient do
      sequence(:name) {|n| "test#{n}" }
    end

    after(:build) do |attr, evaluator|
      attr.name = evaluator.name

      if attr.name.nil?
        FactoryGirl.create(:employee_attribute_definition,
          name: evaluator.name,
          attribute_type: attr.attribute_type,
          account: attr.account
        )

        attr.name = evaluator.name
      end
    end
  end
end

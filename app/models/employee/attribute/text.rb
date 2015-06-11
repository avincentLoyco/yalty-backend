class Employee::Attribute::Text < Employee::Attribute
  serialized_attributes do
    attribute :text, String
  end
end

require 'rspec/expectations'

RSpec::Matchers.define :have_serialized_attribute do |expected|
  match do |actual|
    attribute = actual.class::DataSerializer.attribute_set.map(&:name)

    attribute.include?(expected)
  end

  failure_message do |actual|
    "expected #{actual.class.name} to have serialized attribute #{expected}"
  end

  failure_message_when_negated do |actual|
    "expected #{actual.class.name} not to have serialized attribute #{expected}"
  end
end

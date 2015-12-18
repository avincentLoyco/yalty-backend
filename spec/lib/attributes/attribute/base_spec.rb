require 'rails_helper'

RSpec.describe Attribute::Base do
  it '.attribute_type should return attribute type name' do
    expect(subject.class).to respond_to(:attribute_type)
    expect(subject.class.attribute_type).to eql('Base')
  end

  it '#attribute_type should return attribute type name' do
    expect(subject).to respond_to(:attribute_type)
    expect(subject.attribute_type).to eql('Base')
  end

  describe '.attribute_types' do
    subject { Attribute::Base }

    it 'should respond' do
      is_expected.to respond_to(:attribute_types)
    end

    it 'should respond with an array' do
      expect(subject.attribute_types).to be_a(Array)
    end

    it 'should include inherited models' do
      expect(subject.attribute_types).to include('Child')
    end
  end
end

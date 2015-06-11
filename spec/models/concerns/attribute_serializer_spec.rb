require 'rails_helper'

RSpec.describe AttributeSerializer, type: :model do
  before(:all) do
    Temping.create(:fake_attribute_model) do
      include AttributeSerializer

      with_columns do |t|
        t.string :type
        t.hstore :data
      end

      serialized_attributes
    end
  end

  subject { Class.new(FakeAttributeModel) }

  it { is_expected.to respond_to(:serialized_attributes) }

  describe 'DataSerializer class' do
    subject { super()::DataSerializer }

    it { is_expected.to be < AttributeSerializer::Base }
    it { is_expected.to be < Virtus::Model::Core }

    it { is_expected.to respond_to(:dump) }

    it 'should return a hash on #dump' do
      hash = subject.dump(subject.new)

      expect(hash).to be_kind_of(Hash)
    end

    it { is_expected.to respond_to(:load) }

    it 'should return a DataSerializer on #load' do
      serializer = subject.load({})

      expect(serializer).to be_kind_of(AttributeSerializer::Base)
    end
  end

  context 'with attributes block' do
    subject do
      model = super()

      model.serialized_attributes do
        attribute :text, String
        attribute :number, Integer
      end

      model.new
    end

    it 'should define attribute' do
      attributes = subject.class::DataSerializer.attribute_set.map(&:name)

      expect(attributes).to match([:text, :number])
    end

    it 'should delegate getter to data' do
      expect(subject).to delegate_method(:text).to(:data)
    end

    it 'should delegate setter to data' do
      expect(subject).to delegate_method(:text=).to(:data).with_arguments('another text')
    end

  end
end

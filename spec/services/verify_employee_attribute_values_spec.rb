require 'rails_helper'

RSpec.describe VerifyEmployeeAttributeValues, type: :service do
  before { Account.current = create(:account) }
  subject { VerifyEmployeeAttributeValues.new(params) }
  let(:attribute_name) { 'lastname' }
  let(:params) do
    {
      attribute_name: attribute_name,
      value: value
    }
  end

  context 'when attribute value is valid' do
    context 'value is a string' do
      let(:value) { 'test' }

      it { expect(subject.valid?).to eq true }
      it 'should not return error' do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end

    context 'value is a hash' do
      let(:attribute_name) { 'address' }
      let(:value) {{ city: 'Warsaw', country: 'Poland' }}

      it { expect(subject.valid?).to eq true }
      it 'should not return error' do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end

    context 'value is a nil' do
      let(:value) { nil }

      it { expect(subject.valid?).to eq true }
      it 'should not return error' do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end

    context 'params without attribute name' do
      let(:value) { 'test' }
      before { params.delete(:attribute_name) }

      it { expect(subject.valid?).to eq true }
      it 'should not return error' do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end

    context 'params without value' do
      let(:value) { 'test' }
      before { params.delete(:value) }

      it { expect(subject.valid?).to eq true }
      it 'should not return error' do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end
  end

  context 'when attribute value is not valid' do
    context 'hash send for attribute which require string' do
      let(:value) {{ name: 'test' }}

      it { expect(subject.valid?).to eq false }
      it 'should return error' do
        subject.valid?

        expect(subject.errors[:value]).to eq('Invalid type')
      end
    end

    context 'string send for atrribute which is nested' do
      let(:value) { 'test' }
      let(:attribute_name) { 'address' }

      it { expect(subject.valid?).to eq false }
      it 'should return error' do
        subject.valid?

        expect(subject.errors[:value]).to eq('Invalid type')
      end
    end

    context 'value is in invalid type' do
      let(:value) { ['a'] }

      it { expect(subject.valid?).to eq false }
      it 'should return error' do
        subject.valid?

        expect(subject.errors[:value]).to eq('Invalid type')
      end
    end

    context 'value has missing params' do
      let(:gate_rules) do
        Gate.rules do
          required :foo
        end
      end

      before do
        allow_any_instance_of(ValuesRules).to receive(:gate_rules)
          .with('Address').and_return(gate_rules)
      end

      let(:attribute_name) { 'address' }
      let(:value) {{ city: 'Warsaw', country: 'Poland' }}

      it { expect(subject.valid?).to eq false }
      it 'should return error' do
        subject.valid?

        expect(subject.errors[:foo]).to eq(:missing)
      end
    end
  end
end

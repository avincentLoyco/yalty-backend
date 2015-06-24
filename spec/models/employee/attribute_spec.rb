require 'rails_helper'

RSpec.describe Employee::Attribute, type: :model do
  it { is_expected.to have_db_column(:name).with_options(null: false) }

  it { is_expected.to have_db_column(:type).with_options(null: false) }

  it { is_expected.to have_db_column(:data) }

  it { is_expected.to have_db_column(:employee_id) }
  it { is_expected.to have_db_index(:employee_id) }
  it { is_expected.to belong_to(:employee).inverse_of(:employee_attributes) }
  it { is_expected.to validate_presence_of(:employee) }

  it { is_expected.to have_one(:account).through(:employee) }

  it '.attribute_type should return attribute type name' do
    expect(subject.class).to respond_to(:attribute_type)
    expect(subject.class.attribute_type).to eql('Text')
  end

  describe '.attribute_types' do
    subject { Employee::Attribute }

    before(:all) do
      class Employee::Attribute::Fake < Employee::Attribute; end
    end

    after(:all) do
      Employee::Attribute.send(:remove_const, :Fake)
    end

    it 'should respond' do
      is_expected.to respond_to(:attribute_types)
    end

    it 'should respond with an array' do
      expect(subject.attribute_types).to be_a(Array)
    end

    it 'should include inherited models' do
      expect(subject.attribute_types).to include('Fake')
    end
  end
end

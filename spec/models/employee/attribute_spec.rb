require 'rails_helper'

RSpec.describe Employee::Attribute, type: :model do
  subject! { FactoryGirl.build(:employee_attribute) }

  let (:account) { subject.account }

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

  it { is_expected.to belong_to(:attribute_definition).class_name('Employee::AttributeDefinition') }
  it { is_expected.to validate_presence_of(:attribute_definition) }
  it 'should validate uniqueness of attribute_definition' do
    subject.save!

    attr = FactoryGirl.build(:employee_attribute, name: subject.name, account: account)

    expect(attr).to_not be_valid
  end

  it 'should validate presence of attribute definition' do
    Employee::AttributeDefinition.delete_all

    is_expected.to validate_presence_of(:attribute_definition)
  end

  it 'should be associeted with attribute definition record' do
    attribute_definition = Employee::AttributeDefinition.where(
      name: subject.name,
      attribute_type: subject.attribute_type,
      account: subject.account
    ).first!

    expect(subject.attribute_definition).to be_eql(attribute_definition)
  end

  it '#attribute_definition should be readonly on create' do
    subject.save!

    expect(subject.attribute_definition).to be_readonly
  end

  it '#attribute_definition should be readonly on update' do
    subject.save!
    subject.reload

    expect(subject.attribute_definition).to be_readonly
  end

end

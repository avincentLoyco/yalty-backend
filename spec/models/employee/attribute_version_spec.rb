require 'rails_helper'

RSpec.describe Employee::AttributeVersion, type: :model do
  subject! { FactoryGirl.build(:employee_attribute) }

  let (:account) { subject.account }

  it { is_expected.to have_db_column(:data) }

  it { is_expected.to have_db_column(:employee_id) }
  it { is_expected.to have_db_index(:employee_id) }
  it { is_expected.to belong_to(:employee).inverse_of(:employee_attribute_versions) }
  it { is_expected.to validate_presence_of(:employee) }

  it { is_expected.to have_one(:account).through(:employee) }

  it { is_expected.to belong_to(:attribute_definition).class_name('Employee::AttributeDefinition') }
  it { is_expected.to validate_presence_of(:attribute_definition) }

  it 'should validate uniqueness of attribute_definition' do
    subject.save!

    attr = FactoryGirl.build(:employee_attribute, name: subject.name, employee: subject.employee)

    expect(attr).to_not be_valid
  end

  it 'should validate uniqueness of attribute_definition scoped to employee' do
    subject.save!

    employee = FactoryGirl.create(:employee, account: subject.account)
    attr = FactoryGirl.build(:employee_attribute, name: subject.name, employee: employee)

    expect(attr).to be_valid
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

  it 'should set attribute definition by name on initialize' do
    attribute_definition = FactoryGirl.create(:employee_attribute_definition, name: 'test')
    employee = FactoryGirl.create(:employee, account: attribute_definition.account)

    attr = Employee::AttributeVersion.new(employee: employee, name: 'test')

    expect(attr.attribute_definition).to_not be_nil
    expect(attr.attribute_definition.name).to eql('test')
  end

  it 'should set attribute definition by name on build through employee' do
    attribute_definition = FactoryGirl.create(:employee_attribute_definition, name: 'test')
    employee = FactoryGirl.create(:employee, account: attribute_definition.account)

    attr = employee.employee_attribute_versions.build(name: 'test')

    expect(attr.attribute_definition).to_not be_nil
    expect(attr.attribute_definition.name).to eql('test')
  end

end

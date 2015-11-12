require 'rails_helper'

RSpec.describe ActsAsAttribute do
  subject! {
    FakeActsAsAttribute.new(
      employee: employee,
      attribute_name: attribute_definition.name,
      event: employee.events.first
    )
  }

  let(:employee) { create(:employee, :with_attributes) }
  let(:attribute_definition) {
    create(
      :employee_attribute_definition,
      account: employee.account,
      attribute_type: 'String'
    )
  }

  before(:all) do
    Temping.create(:fake_acts_as_attribute) do
      with_columns do |t|
        t.uuid :employee_id
        t.uuid :attribute_definition_id
        t.uuid :employee_event_id
        t.hstore :data
      end

      include ActsAsAttribute

      belongs_to :event,
        class_name: 'Employee::Event',
        foreign_key: 'employee_event_id',
        inverse_of: :employee_attribute_versions
      belongs_to :employee, required: true
      has_one :account, through: :employee
    end
  end

  it { is_expected.to belong_to(:attribute_definition).class_name('Employee::AttributeDefinition') }
  it { is_expected.to validate_presence_of(:attribute_definition) }

  it 'should delegate attribute_type to attribute_definition' do
    expect(subject.attribute_definition).to receive(:attribute_type)

    subject.attribute_type
  end

  it 'should delegate attribute_name to attribute_definition' do
    expect(subject.attribute_definition).to receive(:name)

    subject.attribute_name
  end

  it 'should delegate value to data' do
    expect(subject.data).to receive(:value)

    subject.value
  end

  it 'should validate uniqueness of attribute_definition' do
    subject.save!

    attr = FakeActsAsAttribute.new(
      employee: subject.employee,
      attribute_name: subject.attribute_name,
      event: employee.events.first
    )

    expect(attr).to_not be_valid
  end

  it 'should validate uniqueness of attribute_definition scoped to employee' do
    subject.save!

    attr = build(:employee_attribute, attribute_name: subject.attribute_name, employee: employee)

    expect(attr).to be_valid
  end

  it 'should validate presence of attribute definition' do
    subject.attribute_definition = nil

    expect { subject.valid? }.to change { subject.errors.messages[:attribute_definition] }
      .to(["can't be blank"])
  end

  it 'should be associeted with attribute definition record' do
    attribute_definition = Employee::AttributeDefinition.where(
      name: subject.attribute_name,
      attribute_type: subject.attribute_type,
      account: employee.account
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
    attribute_definition = create(:employee_attribute_definition, name: 'test')
    employee = create(:employee, account: attribute_definition.account)

    attr = Employee::AttributeVersion.new(employee: employee, attribute_name: 'test')

    expect(attr.attribute_definition).to_not be_nil
    expect(attr.attribute_definition.name).to eql('test')
  end

  it 'should retrieve solo value after set using value=' do
    subject.value = 'Test'

    expect(subject.data.value).to eql('Test')
  end

  it 'should retrieve hash value after set using value=' do
    subject.value = { 'string' => 'A string' }

    expect(subject.data.value).to eql('A string')
  end
end

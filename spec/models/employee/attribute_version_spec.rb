require 'rails_helper'

RSpec.describe Employee::AttributeVersion, type: :model do
  subject! { FactoryGirl.build(:employee_attribute) }

  it { is_expected.to have_db_column(:data) }

  it { is_expected.to have_db_column(:employee_id) }
  it { is_expected.to have_db_index(:employee_id) }
  it { is_expected.to belong_to(:employee).inverse_of(:employee_attribute_versions) }
  it { is_expected.to validate_presence_of(:employee) }

  it { is_expected.to have_one(:account).through(:employee) }

  it { is_expected.to have_db_column(:attribute_definition_id) }

  it { is_expected.to belong_to(:event).class_name('Employee::Event') }
  it { is_expected.to validate_presence_of(:event) }

  it 'should delegate effective_at to event' do
    is_expected.to respond_to(:effective_at)
    expect(subject.effective_at).to eq(subject.event.effective_at)
  end

end

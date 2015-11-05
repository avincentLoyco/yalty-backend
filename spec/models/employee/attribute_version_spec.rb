require 'rails_helper'

RSpec.describe Employee::AttributeVersion, type: :model do
  subject! { build(:employee_attribute) }

  it { is_expected.to have_db_column(:data) }

  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_index(:employee_id) }
  it { is_expected.to belong_to(:employee).inverse_of(:employee_attribute_versions) }
  it { is_expected.to validate_presence_of(:employee) }

  it { is_expected.to have_one(:account).through(:employee) }

  it { is_expected.to have_db_column(:attribute_definition_id) }

  it { is_expected.to belong_to(:event).class_name('Employee::Event') }
  it { is_expected.to validate_presence_of(:event) }

  it { is_expected.to_not validate_presence_of(:order) }
  it { expect { subject.valid? }.to_not change { subject.errors.messages[:order] } }

  it 'should delegate effective_at to event' do
    is_expected.to respond_to(:effective_at)
    expect(subject.effective_at).to eq(subject.event.effective_at)
  end

  context 'order presence validation' do
    let(:definition) { create(:employee_attribute_definition, multiple: true) }
    subject { build(:employee_attribute, attribute_definition: definition, order: nil) }

    it { is_expected.to validate_presence_of(:order) }
    it { expect(subject.valid?).to eq false }
    it { expect { subject.valid? }.to change { subject.errors.messages[:order] } }
  end
end

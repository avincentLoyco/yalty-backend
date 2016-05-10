require 'rails_helper'

RSpec.describe Employee::Event, type: :model do
  subject! { build(:employee_event) }

  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_index(:employee_id) }
  it { is_expected.to belong_to(:employee).inverse_of(:events) }
  it { is_expected.to validate_presence_of(:employee) }

  it { is_expected.to have_one(:account).through(:employee) }

  it { is_expected.to have_db_column(:effective_at) }
  it { is_expected.to validate_presence_of(:effective_at) }

  it { is_expected.to have_db_column(:comment) }

  it { is_expected.to have_db_column(:event_type) }
  it { is_expected.to validate_presence_of(:event_type) }
  it do
    is_expected.to validate_inclusion_of(:event_type)
      .in_array(
        %w{
          default
          hired
        }
      )
  end

  context '#attributes_presence validation' do
    before { allow(Account).to receive(:current) { subject.account } }
    let(:employee) { create(:employee, :with_attributes) }
    subject { employee.events.first }

    context 'when event contain required attributes' do
      subject { build(:employee_event, event_type: 'hired') }

      it { expect(subject.valid?).to eq false }
      it { expect { subject.valid? }.to change {
        subject.errors.messages[:employee_attribute_versions] }
      }
    end

    context 'when event do not have required attributes' do
      before do
        lastname_def = Account.current.employee_attribute_definitions.find_by(name: 'lastname')
        firstname_def = Account.current.employee_attribute_definitions.find_by(name: 'firstname')
        event.employee_attribute_versions.last.update!(
          attribute_definition: lastname_def, data: { value: 'a' }
        )
        event.employee_attribute_versions.first.update!(
          attribute_definition: firstname_def, data: { value: 'b' }
        )
      end

      let(:employee) { create(:employee, :with_attributes) }
      let(:event) { employee.events.first }
      subject { employee.events.first }

      it { expect(subject.valid?).to eq true }
      it { expect { subject.valid? }.to_not change {
        subject.errors.messages[:employee_attribute_versions] }
      }
    end
  end

  context 'employee can have only one hired event' do
    let(:employee) { create(:employee) }
    let(:employee_event) { build(:employee_event, event_type: event_type, employee: employee) }
    subject { employee_event }

    context 'with valid params' do
      let(:event_type) { 'default' }

      it { expect(subject.valid?).to eq true }
      it { expect(employee.events.find_by(event_type: 'hired').valid?).to eq true }
      it { expect { subject.valid? }.to_not change { subject.errors.messages[:event_type] } }
    end

    context 'with invalid params' do
      let(:event_type) { 'hired' }

      it { expect(subject.valid?).to eq false }
      it { expect { subject.valid? }.to change { subject.errors.messages[:event_type] }
        .to include 'Employee can have only one hired event' }
    end
  end
end

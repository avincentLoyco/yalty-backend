require 'rails_helper'

RSpec.describe Employee::Event, type: :model do
  include_context 'shared_context_timecop_helper'

  subject! { build(:employee_event) }

  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_index(:employee_id) }
  it { is_expected.to belong_to(:employee).inverse_of(:events) }
  it { is_expected.to validate_presence_of(:employee) }

  it { is_expected.to have_one(:account).through(:employee) }

  it { is_expected.to have_db_column(:effective_at) }
  it { is_expected.to validate_presence_of(:effective_at) }

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

  context '#hired_and_contract_end_not_in_the_same_date' do
    let(:employee) { create(:employee) }
    let!(:existing_event) do
      create(:employee_event, event_type: 'contract_end', employee: employee)
    end
    subject do
      build(:employee_event, event_type: 'hired', employee: employee, effective_at: effective_at)
    end

    context 'with valid params' do
      let(:effective_at) { existing_event.effective_at + 1.day }

      it { expect(subject).to be_valid }
      it do
        expect { subject.valid? }.to_not change { subject.errors.messages.size }
      end
    end

    context 'with invalid params' do
      let(:effective_at) { existing_event.effective_at }

      it { expect(subject).to_not be_valid }
      it do
        expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
          .to include 'Hired and contract end event can not be at the same date'
      end
    end
  end

  context '#no_two_contract_end_dates_or_hired_events_in_row' do
    let(:employee) { create(:employee) }
    let(:subject_effective_at) { Time.now - 3.years }

    subject do
      build(:employee_event,
        employee: employee, event_type: event_type, effective_at: subject_effective_at)
    end

    shared_examples 'Two contract end or hired events in a row' do
      before do
        if try(:marriage_effective_at)
          create(:employee_event,
            employee: employee, event_type: 'marriage', effective_at: marriage_effective_at)
          employee.reload.events
        end
      end

      it { expect(subject.valid?).to eq false }
      it do
        expect { subject.valid? }.to change { subject.errors.messages[:event_type] }
          .to include (
            "Employee can not two #{event_type} in a row and contract end must have hired event"
          )
      end
    end

    context 'when event has type contract_end' do
      let(:event_type) { 'contract_end' }
      before do
        create(:employee_event,
          employee: employee, event_type: 'contract_end', effective_at: effective_at)
        employee.reload.events
      end

      context 'and previous event is the same' do
        let(:effective_at) { subject.effective_at - 1.week }

        it_behaves_like 'Two contract end or hired events in a row'

        context 'and they are separated by other events' do
          let(:marriage_effective_at) { subject.effective_at - 4.days }
          let(:effective_at) { subject.effective_at - 1.week }

          it_behaves_like 'Two contract end or hired events in a row'
        end
      end

      context 'and next event is the same' do
        let(:effective_at) { subject.effective_at + 1.week }

        it_behaves_like 'Two contract end or hired events in a row'

        context 'and they are separated by other events' do
          let(:marriage_effective_at) { subject.effective_at + 4.days }

          it_behaves_like 'Two contract end or hired events in a row'
        end
      end
    end

    context 'contract end must have hired event' do
      let(:event_type) { 'contract_end' }
      let(:effective_at) { 1.day.ago }

      shared_examples 'Contract end does not have its hired event' do
        it { expect(subject).to_not be_valid }
        it do
          expect { subject.valid? }.to change { subject.errors.messages[:event_type] }
            .to include(
              "Employee can not two #{event_type} in a row and contract end must have hired event"
            )
        end
      end

      context 'when there is only one contract end' do
        before { employee.events.first.update!(event_type: 'marriage') }

        it_behaves_like 'Contract end does not have its hired event'
      end

      context 'when this next employee\'s contract end' do
        before do
          create(:employee_event, event_type: 'contract_end', employee: employee)
          employee.reload.events
        end

        it_behaves_like 'Contract end does not have its hired event'
      end
    end

    context 'when event has type hired' do
      let(:event_type) { 'hired' }

      context 'and previous event is the same' do
        it_behaves_like 'Two contract end or hired events in a row'

        context 'and they are separated by other event' do
          let(:effective_at) { subject.effective_at - 1.hour }
          let(:marriage_effective_at) { subject.effective_at - 1.day }

          it_behaves_like 'Two contract end or hired events in a row'
        end
      end

      context 'and next event is the same' do
        let(:subject_effective_at) { employee.events.first.effective_at - 10.days }

        it_behaves_like 'Two contract end or hired events in a row'

        context 'and they are separated by other event' do
          let(:marriage_effective_at) { subject.effective_at + 1.day }

          it_behaves_like 'Two contract end or hired events in a row'
        end
      end
    end
  end

  describe '#balances_before_hired_date' do
    let(:employee) { create(:employee) }
    let!(:etop) do
      create(
        :employee_time_off_policy,
        :with_employee_balance,
        employee: employee,
        effective_at: employee.hired_date
      )
    end

    let(:update_hired_date) do
      employee.first_employee_event.update!(effective_at: 2.years.from_now)
    end

    it do
      expect { update_hired_date }.to raise_error(
        ActiveRecord::RecordInvalid,
        'Validation failed: There can\'t be balances before hired date'
      )
    end
  end
end

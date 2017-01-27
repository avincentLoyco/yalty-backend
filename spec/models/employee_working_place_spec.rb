require 'rails_helper'

RSpec.describe EmployeeWorkingPlace, type: :model do
  include_context 'shared_context_timecop_helper'

  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:working_place_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:effective_at).of_type(:date) }

  it { is_expected.to validate_presence_of(:employee) }
  it { is_expected.to validate_presence_of(:working_place) }
  it { is_expected.to validate_presence_of(:effective_at) }

  it { is_expected.to have_db_index([:working_place_id, :employee_id, :effective_at].uniq) }

  it { is_expected.to belong_to(:employee) }
  it { is_expected.to belong_to(:working_place) }

  context '#validations' do
    context 'effective_at_cannot_be_before_hired_date and shared_context_join_tables_effective_at' do
      include_context 'shared_context_join_tables_effective_at',
        join_table: :employee_working_place
    end

    context 'first_employee_working_place_at_start_date' do
      context 'when employee is persisted' do
        let!(:employee_working_place) { create(:employee_working_place) }
        subject { employee_working_place.update(effective_at: Time.now - 2.years) }

        context 'with the same as hired event\'s effective_at' do
          before do
            employee_working_place.employee.first_employee_event.update!(
              effective_at: Time.now - 2.years
            )
          end

          it { expect(subject).to eq true }
          it { expect { subject }.to_not change { employee_working_place.errors.messages.count } }
        end

        context 'with different than hired event\'s effective_at' do
          it { expect(subject).to eq false }
          it { expect { subject }.to change { employee_working_place.errors.messages[:effective_at] }
            .to include 'can\'t be set before employee hired date' }
        end
      end

      context 'when employee is not persisted' do
        subject { build(:employee_working_place) }

        context 'with the same as hired event\'s effective_at' do
          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
        end

        context 'with different than hired event\'s effective_at' do
          before { subject.effective_at = Time.now - 1.year }

          it { expect(subject.valid?).to eq false }
          it { expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
            .to include 'can\'t be set before employee hired date' }
        end
      end
    end
  end

  context 'callbacks' do
    let!(:account) { create(:account) }
    let!(:employee) { create(:employee, account: account) }
    let!(:working_place) { create(:working_place, account: account) }
    let(:ewp) { build(:employee_working_place, employee: employee, working_place: working_place) }

    context '.create_reset_policy' do
      before do
        Account.current = account
        params = {
          effective_at: Time.zone.parse('2016/03/01'),
          event_type: 'contract_end',
          employee: { id: employee.id }
        }
        CreateEvent.new(params, {}).call
      end

      it { expect { ewp.save! }.to change(EmployeeWorkingPlace, :count).by(2) }
      it 'last presence policy is reset' do
        ewp.save!
        expect(employee.reload.working_places.where(reset: true).last.present?).to be(true)
      end
    end
  end
end

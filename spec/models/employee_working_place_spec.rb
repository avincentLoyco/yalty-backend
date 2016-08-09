require 'rails_helper'

RSpec.describe EmployeeWorkingPlace, type: :model do
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
            .to include 'can\'t be set before employee hired_date' }
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
            .to include 'can\'t be set before employee hired_date' }
        end
      end
    end

    context '#effective_at_newer_than_first_event' do
      let!(:employee_working_place) { create(:employee_working_place) }

      context 'when employee working place is first' do
        subject { employee_working_place }

        context 'and created' do
          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
        end

        context 'and updated' do
          before do
            employee_working_place.employee.first_employee_event.update!(
              effective_at: Time.now - 1.week
            )
            employee_working_place.effective_at = Time.now - 1.week
          end

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
        end
      end

      context 'when employee working place is not first' do
        subject { new_working_place }
        let(:new_working_place) do
          build(:employee_working_place,
            effective_at: effective_at, employee: employee_working_place.employee
          )
        end

        context 'and new effective_at after first effective at' do
          let(:effective_at) { employee_working_place.effective_at + 1.week }

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
        end

        context 'and new effective at before first effective at' do
          let(:effective_at) { employee_working_place.effective_at - 1.week }

          it { expect(subject.valid?).to eq false }
          it { expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
            .to include 'Must be after first employee working place effective_at' }
        end

        context 'and new effective at is the same like first effective at' do
          let(:effective_at) { employee_working_place.effective_at }

          it { expect(subject.valid?).to eq false }
          it { expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
            .to include 'Must be after first employee working place effective_at' }
        end
      end
    end
  end
end

require 'rails_helper'

RSpec.describe TimeOff, type: :model do
  include_context 'shared_context_account_helper'

  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:start_time).of_type(:datetime).with_options(null: false) }
  it { is_expected.to have_db_column(:end_time).of_type(:datetime).with_options(null: false) }
  it { is_expected.to have_db_column(:employee_id).of_type(:uuid).with_options(null: false) }
  it { is_expected.to have_db_column(:time_off_category_id)
    .of_type(:uuid).with_options(null: false) }

  it { is_expected.to have_db_index(:time_off_category_id) }
  it { is_expected.to have_db_index(:employee_id) }

  it { is_expected.to belong_to(:employee) }
  it { is_expected.to belong_to(:time_off_category) }
  it { is_expected.to have_one(:employee_balance) }

  it { is_expected.to validate_presence_of(:start_time) }
  it { is_expected.to validate_presence_of(:end_time) }
  it { is_expected.to validate_presence_of(:time_off_category_id) }
  it { is_expected.to validate_presence_of(:employee_id) }

  context 'validations' do
    let(:employee_policy) { build(:employee_time_off_policy) }
    before do
      allow_any_instance_of(Employee)
        .to receive(:active_policy_in_category_at_date) { employee_policy }
    end

    context '#start_time_after_employee_creation' do
      subject { build(:time_off, start_time: effective_at) }

      context 'with invalid data' do
        let(:effective_at) { Time.now - 10.years }

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] }
          .to include('Can not be added before employee start date') }
      end

      context 'with valid params' do
        let(:effective_at) { Time.now - 3.years }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
      end
    end

    context '#end_time_after_start_time' do
      subject { build(:time_off, end_time: end_time)  }

      context 'when valid data' do
        let(:end_time) { Time.now + 1.month }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages } }
      end

      context 'when invalid data' do
        let(:end_time) { Time.now - 1.month }

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:end_time] } }
      end
    end

    context '#time_off_policy_presence' do
      subject { build(:time_off) }

      context 'with valid data' do
        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages } }
      end

      context 'with invalid data' do
        before do
          allow_any_instance_of(Employee)
            .to receive(:active_policy_in_category_at_date) { nil }
        end

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:employee] } }
      end
    end

    context '#does_not_overlap_with_other_users_time_offs' do
      let(:employee) { create(:employee) }
      subject do
        build(:time_off, start_time: '1/1/2016', end_time: '5/1/2016', employee_id: employee.id)
      end

      context 'when there are no another time offs' do
        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
      end

      context 'when there is another time off' do
        let(:start_time) { '6/1/2016' }
        let(:end_time) { '10/1/2016' }
        let!(:time_off) do
          create(:time_off, start_time: start_time, end_time: end_time, employee: employee)
        end

        context 'and it does not overlaps' do
          let(:start_time) { '6/1/2016' }

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }

          context 'end_time eqal existing time off start_time' do
            let(:start_time) { '5/1/2016' }

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
          end

          context 'start_time equal existing time off end_time' do
            let(:start_time) { '31/12/2015' }
            let(:end_time) { '1/1/2016' }

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
          end
        end

        context 'and it overlaps' do
          context 'start_time and end_time are in existing time off period' do
            let(:start_time) { '2/1/2016' }
            let(:end_time) { '4/1/2016' }

            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] }
              .to include 'Time off in period already exist' }
          end

          context 'start_time and end_time are in existing time off period' do
            let(:start_time) { '1/1/2016' }
            let(:end_time) { '5/1/2016' }

            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] }
              .to include 'Time off in period already exist' }
          end

          context 'start_time in exsiting time off period' do
            let(:start_time) { '3/1/2016' }

            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] }
              .to include 'Time off in period already exist' }
          end

          context 'end_time in existing time off period' do
            let(:start_time) { '31/12/2015' }
            let(:end_time) { '3/1/2016' }

            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] }
              .to include 'Time off in period already exist' }
          end
        end
      end
    end
  end

  context 'scopes' do
    include_context 'shared_context_timecop_helper'

    context '#for_employee_in_period' do
      subject { TimeOff.for_employee_in_period(employee, start_date, end_date).pluck(:id) }
      let(:start_date) { Time.now + 1.day }
      let(:end_date) { Time.now + 4.days }
      let(:employee) { create(:employee) }

      context 'when employee does not have time offs' do
        it { expect(subject.size).to eq 0 }
      end

      context 'when employee has time_offs in period' do
        context 'when time offs start or end dates are in the scope' do
          let!(:time_offs) do
            [[Time.now, Time.now + 1.day], [Time.now + 2.days, Time.now + 3.days],
             [Time.now + 4.days, Time.now + 5.days]].map do |start_time, end_time|
               create(:time_off, employee: employee, start_time: start_time, end_time: end_time)
             end
          end
          it { expect(subject.size).to eq 3 }

          it { expect(subject).to include(time_offs.first.id) }
          it { expect(subject).to include(time_offs.second.id) }
          it { expect(subject).to include(time_offs.last.id) }

          context 'while time off is not in the scope' do
            let(:start_date) { Time.now + 2.days }

            it { expect(subject.size).to eq 2 }

            it { expect(subject).to include(time_offs.second.id) }
            it { expect(subject).to include(time_offs.last.id) }

            it { expect(subject).to_not include(time_offs.first.id) }
          end
        end

        context 'when time offs start and end dates are outside the scope' do
          let!(:time_off) do
            create(:time_off,
              start_time: Time.now + 1.day, end_time: Time.now + 4.days, employee: employee)
          end

          it { expect(subject.size).to eq 1 }
          it { expect(subject).to include(time_off.id) }
        end
      end
    end
  end
 end

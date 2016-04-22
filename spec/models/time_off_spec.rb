require 'rails_helper'

RSpec.describe TimeOff, type: :model do
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
        .to receive(:active_related_time_off_policy) { employee_policy }
    end

    context '#start_time_after_employee_creation' do
      subject { build(:time_off, start_time: Time.now - 1.year) }

      context 'with valid data' do
        before do
          allow_any_instance_of(Employee).to receive(:created_at) { Time.now }
        end

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] }
          .to include('Can not be added before employee creation') }
      end

      context 'with invalid params' do
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
            .to receive(:active_related_time_off_policy) { nil }
        end

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:employee] } }
      end
    end
  end
end

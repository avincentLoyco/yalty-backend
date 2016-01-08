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
  it { is_expected.to have_many(:employee_balances) }

  it { is_expected.to validate_presence_of(:start_time) }
  it { is_expected.to validate_presence_of(:end_time) }
  it { is_expected.to validate_presence_of(:time_off_category_id) }
  it { is_expected.to validate_presence_of(:employee_id) }

  context 'end time validation' do
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
end

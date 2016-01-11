require 'rails_helper'

RSpec.describe TimeOffPolicy, type: :model do
  it { is_expected.to have_db_column(:policy_type).of_type(:string).with_options(null: false) }
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:end_time).of_type(:date).with_options(null: false) }
  it { is_expected.to have_db_column(:start_time).of_type(:date).with_options(null: false) }
  it { is_expected.to have_db_column(:amount).of_type(:integer) }

  it { is_expected.to have_db_index(:time_off_category_id) }

  it { is_expected.to validate_presence_of(:policy_type) }
  it { is_expected.to validate_presence_of(:end_time) }
  it { is_expected.to validate_presence_of(:start_time) }
  it { is_expected.to validate_presence_of(:time_off_category) }
  it { is_expected.to validate_inclusion_of(:policy_type).in_array(%w(counter balance)) }
  it { is_expected.to validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }

  context 'end time validation' do
    subject { build(:time_off_policy, end_time: end_time)  }

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

require 'rails_helper'

RSpec.describe TimeOffPolicy, type: :model do
  it { is_expected.to have_db_column(:policy_type).of_type(:string).with_options(null: false) }
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:end_day).of_type(:integer).with_options(null: true) }
  it { is_expected.to have_db_column(:end_month).of_type(:integer).with_options(null: true) }
  it { is_expected.to have_db_column(:start_day).of_type(:integer).with_options(null: false) }
  it { is_expected.to have_db_column(:start_month).of_type(:integer).with_options(null: false) }
  it { is_expected.to have_db_column(:amount).of_type(:integer)
    .with_options(null: true) }
  it { is_expected.to have_db_column(:years_to_effect).of_type(:integer)
    .with_options(null: true) }

  it { is_expected.to have_db_index(:time_off_category_id) }

  it { is_expected.to validate_presence_of(:policy_type) }
  it { is_expected.to validate_presence_of(:start_day) }
  it { is_expected.to validate_presence_of(:start_month) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:time_off_category) }
  it { is_expected.to validate_inclusion_of(:policy_type).in_array(%w(counter balancer)) }
  it { is_expected.to validate_numericality_of(:years_to_effect).is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_numericality_of(:start_day).is_greater_than_or_equal_to(1) }
  it { is_expected.to validate_numericality_of(:start_month).is_greater_than_or_equal_to(1) }

  let(:start_day) { 1 }
  let(:start_month) { 1 }
  let(:end_day) { 1 }
  let(:end_month) { 4 }
  let(:amount){ 20 }
  let(:policy_type) { 'balancer' }
  let(:time_off_policy) do
    build(:time_off_policy,
      start_day: start_day,
      start_month: start_month,
      end_day: end_day,
      end_month: end_month,
      amount: amount,
      policy_type: policy_type
    )
  end
  context "with valid arguments" do
    context "for balancer policies" do
      context "without end dates" do
        let(:end_day) { nil }
        let(:end_month) { nil }

        it { expect(time_off_policy).to be_valid }
      end

      context "with all attributes" do
        it { expect(time_off_policy).to be_valid }
      end
    end

    context "for counter policies" do
      context "without end dates" do
        let(:end_day) { nil }
        let(:end_month) { nil }
        let(:amount) { nil }
        let(:policy_type) { 'counter' }

        it { expect(time_off_policy).to be_valid }
      end
    end
  end

  context 'with invalid arguments error messages' do
    subject { time_off_policy }
    before { time_off_policy.valid? }

    context 'for counter type' do
      let(:policy_type) { 'counter' }

      it { expect(time_off_policy).to validate_absence_of(:amount) }
    end

    context 'for balancer type' do
      it { expect(time_off_policy).to validate_presence_of(:amount) }
    end

    context 'when start date is on the 29 of february' do
      let(:start_day) { 29 }
      let(:start_month) { 2 }
      it { expect(subject).not_to be_valid }
      it { expect(subject.errors[:start_day]).
        to include '29 of February is not an allowed day'
      }
    end

    context 'when end date is on the 29 of february' do
      let(:end_day) { 29 }
      let(:end_month) { 2 }

      it { expect(subject).not_to be_valid }
      it { expect(subject.errors[:end_day]).
        to include '29 of February is not an allowed day' }
    end

    context 'when start_month is not valid' do
      let(:start_month) { 13 }
      it { expect(subject).not_to be_valid }
      it { expect(subject.errors[:start_month]).to include 'invalid month number' }
    end

    context 'when end_month is not valid' do
      let(:end_month) { 20 }

      it { expect(subject).not_to be_valid }
      it { expect(subject.errors[:end_month]).to include 'invalid month number' }
    end

    context 'when start_day is not valid' do
      let(:start_day) { 40 }

      it { expect(subject).not_to be_valid }
      it { expect(subject.errors[:start_day]).
        to include 'invalid day number given for this month'
      }
    end

    context 'when end_day is not valid' do
      let(:end_day) { 45 }

      it { expect(subject).not_to be_valid }
      it { expect(subject.errors[:end_day]).
        to include 'invalid day number given for this month'
      }
    end

    context 'when policy is of type balancer and' do
      context 'end_day is present but end_month is nil' do
        let(:end_day) { nil }

        it { expect(subject).not_to be_valid }
        it { expect(subject.errors[:end_day]).to include "is not a number", "can't be blank" }
      end

      context 'and end_day is present but end_month is nil' do
        let(:end_month) { nil }

        it { expect(subject).not_to be_valid }
        it { expect(subject.errors[:end_month]).to include "is not a number", "can't be blank" }
      end
    end

    context 'when policy is of type counter and end_day and end_month are not nil' do
      let(:policy_type) { 'counter' }

      it { expect(subject).not_to be_valid }
      it { expect(subject.errors[:end_day]).to include "Should be null for this type of policy" }
      it { expect(subject.errors[:end_month]).to include "Should be null for this type of policy" }
    end

    context 'when start date is after end date' do
      let(:start_month) { 10 }

      it { expect(subject).not_to be_valid }
      it { expect(subject.errors[:end_month]).to include "Must be after start month" }
    end

    context 'when end month and end day given' do
      let(:years) { 1 }
      subject { build(:time_off_policy, end_day: 1, end_month: 4, years_to_effect: years) }

      it { expect(subject.valid?).to eq true }
      it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }

      context 'and years to effect equal nil' do
        let(:years) { nil }

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:end_month] }
          .to include 'Must be empty when years to effect not given'}
        it { expect { subject.valid? }.to change { subject.errors.messages[:end_day] }
          .to include 'Must be empty when years to effect not given'}
      end
    end
  end
end

require "rails_helper"

RSpec.describe PresencePolicy, type: :model do
  let(:employee) { create(:employee, :with_presence_policy) }
  let(:account) { create(:account) }

  subject do
    create(:presence_policy, :with_presence_day, account: account)
  end

  it { is_expected.to have_db_column(:name).of_type(:string) }
  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:occupation_rate).of_type(:float) }
  it { is_expected.to have_many(:employees) }
  it { is_expected.to have_many(:presence_days) }
  it { is_expected.to have_many(:time_entries) }
  it { is_expected.to have_many(:employee_presence_policies) }
  it { is_expected.to belong_to(:account) }
  it { is_expected.to validate_presence_of(:account_id) }
  it { is_expected.to validate_presence_of(:name) }
  it do
    is_expected.to validate_numericality_of(:occupation_rate)
      .is_less_than_or_equal_to(1)
      .is_greater_than_or_equal_to(0)
  end

  context "scopes" do
    context ".active_for_employee" do
      let(:presence_policy) { create(:presence_policy) }

      subject { described_class.active_for_employee(employee.id, Time.now) }

      it { expect(subject.valid?).to eq(true) }

      it { expect(subject.account_id).to eq(employee.account_id) }
      it { expect(subject.id).not_to eq(presence_policy.id) }
    end

    context ".for_account" do
      let(:account) { create(:account) }
      let!(:presence_policies) do
        create_list(:presence_policy, 3, account: account) <<
          account.default_full_time_presence_policy
      end
      let!(:other_presence_policies) { create_list(:presence_policy, 3) }

      subject(:for_account_scope) { described_class.for_account(account.id) }

      it "returns presence policies only for given account" do
        expect(for_account_scope).to match_array(presence_policies)
      end
    end
  end

  context ".standard_day_duration" do
    context "when presence_days are empty" do
      let!(:policy) { create(:presence_policy, presence_days: []) }

      it { expect(policy.standard_day_duration).to eq nil }
    end

    context "when presence_days aren't empty" do
      let!(:policy) { create(:presence_policy) }

      let!(:presence_day1) do
        create(:presence_day, order: 1, presence_policy: policy).tap do |pd|
          pd.time_entries <<
            create(:time_entry, presence_day: pd, start_time: "10:00", end_time: "11:00")
          pd.time_entries <<
            create(:time_entry, presence_day: pd, start_time: "12:00", end_time: "13:20")
          pd.update_minutes!
        end
      end
      let!(:presence_day2) do
        create(:presence_day, order: 2, presence_policy: policy).tap do |pd|
          pd.time_entries <<
            create(:time_entry, presence_day: pd, start_time: "10:00", end_time: "12:40")
          pd.update_minutes!
        end
      end
      let!(:presence_day3) { create(:presence_day, order: 3, minutes: 0, presence_policy: policy) }
      let!(:presence_day4) { create(:presence_day, order: 4, presence_policy: policy) }

      it { expect(policy.standard_day_duration).to eq 150 }
    end
  end

  describe ".default_full_time?" do
    let(:presence_policy) { create(:presence_policy, account: account) }

    context "when presence policy is marked as default full time" do
      before { account.update!(default_full_time_presence_policy_id: presence_policy.id) }

      it { expect(presence_policy.default_full_time?).to eq true }
    end

    context "when presence policy is not marked as default full time" do
      it { expect(presence_policy.default_full_time?).to eq false }
    end
  end

  context "callbacks" do
    context ".trigger_intercom_update" do
      let!(:account) { create(:account) }
      let(:policy) { build(:presence_policy, account: account) }

      it "should invoke trigger_intercom_update method" do
        expect(policy).to receive(:trigger_intercom_update)
        policy.save!
      end

      it "should trigger create_or_update_on_intercom on account" do
        expect(account).to receive(:create_or_update_on_intercom).with(true)
        policy.save!
      end
    end
  end
end

require "rails_helper"

RSpec.describe PresencePolicy, type: :model do
  let(:employee) { create(:employee, :with_presence_policy) }
  let(:full_time) { false }
  let(:account) { create(:account) }

  subject do
    create(:presence_policy, :with_presence_day, default_full_time: full_time, account: account)
  end

  it { is_expected.to have_db_column(:name).of_type(:string) }
  it { is_expected.to have_db_column(:standard_day_duration).of_type(:integer) }
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
      let!(:presence_policies) { create_list(:presence_policy, 3, account: account) }
      let!(:other_presence_policies) { create_list(:presence_policy, 3) }
      let(:all_presence_policies) { presence_policies << account.presence_policies.full_time }

      subject(:for_account_scope) { described_class.for_account(account.id) }

      it "returns presence policies only for given account" do
        expect(for_account_scope.count).to eq(4)
        expect(for_account_scope).to match_array(all_presence_policies)
      end
    end

    context ".full-time" do
      let(:presence_policy) { create(:presence_policy, default_full_time: true) }
      let(:account) { presence_policy.account }
      it do
        presence_policy.save!
        expect(account.presence_policies.reload.full_time).to eq(presence_policy)
      end
    end
  end

  context "callbacks" do
    context ".set_standard_day_duration" do
      let(:presence_days) { build_list(:presence_day, 3, minutes: 140) }
      let!(:policy) { create(:presence_policy, presence_days: presence_days) }

      it { expect(policy.reload.standard_day_duration).to eq(140) }

      context "there already is standard_day_duration" do
        subject { policy.update!(name: "test") }

        it { expect { subject }.to_not change { policy.reload.standard_day_duration } }
      end

      context "standard_day_duration is set manueally" do
        subject { policy.update!(standard_day_duration: 80) }

        it { expect { subject }.to change { policy.reload.standard_day_duration }.from(140).to(80) }
      end
    end

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

  context "sets one default policy" do
    let!(:full_time_presence_policy) do
      create(:presence_policy, default_full_time: true, account: account)
    end

    context "when new policy is default" do
      let(:full_time) { true }

      it "changes existing default policy to not default" do
        subject.save!
        expect(full_time_presence_policy.reload.default_full_time).to eq(false)
      end

      it do
        expect(subject.default_full_time).to eq(true)
      end
    end

    context "when new policy isnt default" do
      let(:full_time) { false }

      it "does not change existing default policy" do
        subject
        expect(full_time_presence_policy.reload.default_full_time).to eq(true)
      end
      it { expect(subject.default_full_time).to eq(false) }
    end
  end
end

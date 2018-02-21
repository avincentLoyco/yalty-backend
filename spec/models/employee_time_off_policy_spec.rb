require "rails_helper"

RSpec.describe EmployeeTimeOffPolicy, type: :model do
  let(:etop) { create(:employee_time_off_policy) }

  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_policy_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_category_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:effective_at).of_type(:date) }
  it { is_expected.to have_db_column(:occupation_rate).of_type(:float) }

  it { is_expected.to validate_presence_of(:employee_id) }
  it { is_expected.to validate_presence_of(:time_off_policy_id) }
  it { is_expected.to validate_presence_of(:effective_at) }

  it do
    is_expected.to validate_numericality_of(:occupation_rate)
      .is_less_than_or_equal_to(1)
      .is_greater_than_or_equal_to(0)
  end
  it { is_expected.to have_db_index([:employee_id, :time_off_category_id, :effective_at]) }
  it "" do
    is_expected.to have_db_index([:employee_id, :time_off_category_id, :effective_at]).unique
  end

  it "the category_id must be the one to which the policy belongs" do
    expect(etop.time_off_category_id).to eq(etop.time_off_policy.time_off_category_id)
  end

  describe "effective_at_cannot_be_before_hired_date and shared_context_join_tables_effective_at" do
    include_context "shared_context_join_tables_effective_at",
      join_table: :employee_time_off_policy
  end

  describe "#balances_without_valid_policy_present?" do
    subject { create(:employee_time_off_policy) }
    let!(:employee_balance) do
      create(:employee_balance, :with_time_off,
        employee: subject.employee, time_off_category: subject.time_off_category)
    end

    context "on update" do
      before { subject.effective_at = employee_balance.effective_at + 1.month }

      it { expect(subject.valid?).to eq false }
      it do
        expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
          .to include "Can't change if there are time offs after and there is no previous policy"
      end
    end

    context "on destroy" do
      it { expect(subject.destroy).to eq false }
      it do
        expect { subject.destroy }.to change { subject.errors.messages[:effective_at] }
          .to include "Can't remove if there are time offs after and there is no previous policy"
      end
    end
  end

  describe "#balances_without_valid_policy_present?" do
    subject { create(:employee_time_off_policy) }
    let!(:employee_balance) do
      create(:employee_balance, :with_time_off,
        employee: subject.employee, time_off_category: subject.time_off_category)
    end

    context "on update" do
      before { subject.effective_at = employee_balance.effective_at + 1.month }

      it { expect(subject.valid?).to eq false }
      it do
        expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
          .to include "Can't change if there are time offs after and there is no previous policy"
      end
    end

    context "on destroy" do
      it { expect(subject.destroy).to eq false }
      it do
        expect { subject.destroy }.to change { subject.errors.messages[:effective_at] }
          .to include "Can't remove if there are time offs after and there is no previous policy"
      end
    end
  end

  describe "#verify_not_change_of_policy_type_in_category" do
    let(:category) { create(:time_off_category, account: account) }
    let(:account) { create(:account) }
    let(:employee) {create(:employee, account: account) }
    context "when there are existing etops" do
      let(:topBalancer) { create(:time_off_policy, time_off_category: category) }
      let!(:etopBalancer) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: topBalancer)
      end

      context "in the same category" do
        let(:topCounter) { create(:time_off_policy, :as_counter, time_off_category: category) }
        let(:etopCounter) do
          build(:employee_time_off_policy, employee: employee, time_off_policy: topCounter)
        end

        it "" do
          etopCounter.valid?
          expected_message = "The employee has an existing policy of different type in the category"
          expect(etopCounter.errors.messages[:policy_type]).to eq([expected_message])
        end
      end

      context "but not in this category" do
        let(:other_category) { create(:time_off_category, account: account) }
        let(:topCounter) { create(:time_off_policy, :as_counter, time_off_category: other_category) }
        let(:etopCounter) do
          build(:employee_time_off_policy, employee: employee, time_off_policy: topCounter)
        end

        it "" do
          expect(etopCounter).to be_valid
        end
      end
    end
  end

  describe "custom validations" do
    context "#no_balances_after_effective_at" do
      let(:employee) { create(:employee) }
      let(:effective_at) { Time.now + 1.day }
      let!(:balance) { create(:employee_balance, effective_at: effective_at, employee: employee) }
      let(:policy) { TimeOffPolicy.not_reset.first }
      let(:new_policy) do
        build(:employee_time_off_policy,
          employee: balance.employee, time_off_policy: policy, effective_at: Time.now - 4.years
        )
      end

      subject { new_policy }

      context "when there is no employee balance in a future" do
        let(:effective_at) { Time.now - 5.years }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
      end

      context "when there is employee balance in the future" do
        let(:effective_at) { Time.now - 2.years }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
      end
    end
  end

  context "callbacks" do
    let!(:account) { create(:account) }
    let!(:category) { create(:time_off_category, account: account) }
    let!(:employee) { create(:employee, account: account) }
    let!(:policy) { create(:time_off_policy, time_off_category: category) }
    let(:etop) do
      build(:employee_time_off_policy, :with_employee_balance, employee: employee,
        time_off_policy: policy)
    end

    context ".trigger_intercom_update" do
      it "should invoke trigger_intercom_update" do
        expect(etop).to receive(:trigger_intercom_update)
        etop.save!
      end

      it "should trigger intercom update on account" do
        expect(account).to receive(:create_or_update_on_intercom).with(true)
        etop.save!
      end

      context "with user" do
        let!(:user) { create(:account_user, account: account, employee: employee) }
        let!(:employee) { create(:employee, account: account) }

        it "should trigger intercom update on user" do
          expect(user).to receive(:create_or_update_on_intercom).with(true)
          etop.save!
        end
      end

      context "without user" do
        it "should not trigger intercom update on user" do
          expect_any_instance_of(Account::User)
            .not_to receive(:create_or_update_on_intercom).with(true)
          etop.save!
        end
      end
    end
  end
end

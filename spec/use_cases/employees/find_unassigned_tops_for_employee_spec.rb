# frozen_string_literal: true

require "rails_helper"

RSpec.describe Employees::FindUnassignedTopsForEmployee do
  context "#call" do
    subject { described_class.new.call(employee) }

    let(:account) { build(:account) }
    let(:employee) { build(:employee, account: account) }
    let(:etop) { build(:employee_time_off_policy, time_off_policy: assigned_top) }
    let(:assigned_top) { build(:time_off_policy) }
    let(:unassigned_top) { build(:time_off_policy) }
    let(:account_tops) { class_double(TimeOffPolicy, not_reset: [assigned_top, unassigned_top]) }

    before do
      allow(employee).to receive(:time_off_policy_ids).and_return([etop.time_off_policy_id])
      allow(employee.account).to receive(:time_off_policies).and_return(account_tops)
    end

    it { expect(subject).to eq([unassigned_top]) }
  end
end

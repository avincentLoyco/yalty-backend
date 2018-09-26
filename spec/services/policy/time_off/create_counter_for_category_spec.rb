require "rails_helper"

RSpec.describe Policy::TimeOff::CreateCounterForCategory do
  include_context "shared_context_account_helper"
  # include_context "shared_context_timecop_helper"

  before do
    Account.current = account
    allow(TimeOffCategory).to receive(:find) { time_off_category }
  end

  subject { described_class.call(time_off_category) }

  let(:account) { create(:account) }
  let(:time_off_category) { create(:time_off_category, name: "University Days") }

  it { expect(subject.name).to eq(time_off_category.name) }
  it { expect(subject.policy_type).to eq("counter")}

  context "when account has active employees" do
    before do
      employees
    end

    let(:employees) { create_list(:employee_hired_now, 2, account: account) }

    it "creates employee time off policies for active employees" do
      time_off_policy = subject
      expect(EmployeeTimeOffPolicy.all.pluck(:time_off_policy_id, :employee_id)).to eq(
        [
          [time_off_policy.id, employees[0].id],
          [time_off_policy.id, employees[1].id],
        ]
      )
    end
  end
end

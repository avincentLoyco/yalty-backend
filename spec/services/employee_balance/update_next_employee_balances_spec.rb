require "rails_helper"

RSpec.describe UpdateNextEmployeeBalances, jobs: true do
  subject { described_class.new(adjustment_balance).call }

  let(:adjustment_balance) { create(:employee_balance) }

  before do
    allow(PrepareEmployeeBalancesToUpdate).to receive(:call).and_call_original
  end

  context "when there are no balances in future" do
    it "doesn't enqueue UpdateBalanceJob" do
      expect { subject }.not_to have_enqueued_job(UpdateBalanceJob)
    end

    it "doesn't call PrepareEmployeeBalancesToUpdate service" do
      subject

      expect(PrepareEmployeeBalancesToUpdate).not_to have_received(:call)
    end
  end


  context "when there are balances in future" do
    before do
      create(
        :employee_balance,
        employee: adjustment_balance.employee,
        time_off_category: adjustment_balance.time_off_category,
        effective_at: adjustment_balance.effective_at + 1.day
      )
    end

    it "enqueues UpdateBalanceJob" do
      expect { subject }.to have_enqueued_job(UpdateBalanceJob).with(adjustment_balance.id)
    end

    it "calls PrepareEmployeeBalancesToUpdate service" do
      subject

      expect(PrepareEmployeeBalancesToUpdate).to have_received(:call).with(adjustment_balance)
    end
  end
end

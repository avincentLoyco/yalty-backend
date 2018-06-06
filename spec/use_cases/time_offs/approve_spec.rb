# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimeOffs::Approve do
  before do
    allow(observer).to receive(:update)
  end

  let(:use_case) do
    described_class
      .new(time_off)
      .add_observers(observer)
      .on(:success)      { :ok }
      .on(:not_modified) { :not_modified }
  end

  let(:observer) { double }

  let(:time_off) do
    # enable status change temporarily for factory to build
    TimeOff.aasm(:approval_status).state_machine.config.no_direct_assignment = false

    build(:time_off, approval_status: approval_status) do
      # and disable again
      TimeOff.aasm(:approval_status).state_machine.config.no_direct_assignment = true
    end
  end

  describe "#call" do
    context "when status was pending" do
      let(:approval_status) { :pending }

      before do
        allow(CreateEmployeeBalance).to receive(:call)
      end

      it "updates time off status to approved" do
        expect { use_case.call }.to change { time_off.approved? }.to(true)
      end

      it "calls success callback" do
        expect(use_case.call).to eq :ok
      end

      it "calls create balance callback" do
        use_case.call
        expect(CreateEmployeeBalance).to have_received(:call).with(
          time_off.time_off_category_id,
          time_off.employee_id,
          time_off.employee.account_id,
          time_off_id: time_off.id,
          balance_type: "time_off",
          resource_amount: time_off.balance,
          effective_at: time_off.end_time
        )
      end

      it "notifies observers" do
        use_case.call

        expect(observer).to have_received(:update)
          .with(notification_type: :time_off_approved, resource: time_off)
      end
    end

    context "when status was already approved" do
      let(:approval_status) { :approved }

      it "doesn't change status" do
        expect { use_case.call }.not_to change { time_off.approval_status }
      end

      it "calls not_modified callback" do
        expect(use_case.call).to eq :not_modified
      end

      it "doesn't notify observers" do
        use_case.call

        expect(observer).not_to have_received(:update)
      end
    end

    context "when status was declined" do
      let(:approval_status) { :declined }

      it "calls error callback" do
        expect { use_case.call }.to raise_error AASM::InvalidTransition
      end
    end
  end
end

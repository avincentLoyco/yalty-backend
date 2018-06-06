# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimeOffs::Update do
  before do
    allow(TimeOffs::Approve).to receive(:call).and_call_original
    allow(TimeOffs::Decline).to receive(:call).and_call_original
    allow(observer).to receive(:update)
  end

  let(:use_case) do
    described_class
      .new(time_off, attributes)
      .add_observers(observer)
      .on(:success) { :ok }
  end

  let(:time_off) do
    # enable status change temporarily for factory to build
    TimeOff.aasm(:approval_status).state_machine.config.no_direct_assignment = false

    create(:time_off, approval_status: approval_status) do
      # and disable again
      TimeOff.aasm(:approval_status).state_machine.config.no_direct_assignment = true
    end
  end

  let(:attributes) do
    {
      start_time: start_time,
      end_time: end_time,
    }
  end
  let(:approval_status) { :pending }
  let(:start_time) { time_off.start_time + 3.days }
  let(:end_time) { start_time + 3.months }
  let(:observer) { double }

  describe "#call" do
    it "updates time off attributes" do
      expect { use_case.call }
        .to change { time_off.start_time }.to(start_time)
        .and change { time_off.end_time }.to(end_time)
    end

    it "calls success callback" do
      expect(use_case.call).to eq :ok
    end

    it "doesn't notify observers" do
      use_case.call

      expect(observer).not_to have_received(:update)
    end

    context "when status changed to approved", jobs: true do
      before do
        attributes[:approval_status] = "approved"
        allow(PrepareEmployeeBalancesToUpdate).to receive(:call).and_call_original
      end

      it "calls Approve use case" do
        use_case.call
        expect(TimeOffs::Approve).to have_received(:call).with(time_off)
      end

      it "calls PrepareEmployeeBalancesToUpdate service" do
        use_case.call
        expect(PrepareEmployeeBalancesToUpdate).to have_received(:call)
      end

      it "enques UpdateBalanceJob" do
        expect { use_case.call }.to have_enqueued_job(UpdateBalanceJob)
      end

      it "doesn't call Decline use case" do
        use_case.call
        expect(TimeOffs::Decline).not_to have_received(:call)
      end

      it "notifies observers" do
        use_case.call

        expect(observer).to have_received(:update)
          .with(notification_type: :time_off_approved, resource: time_off)
      end
    end

    context "when status changed to declined" do
      before do
        attributes[:approval_status] = "declined"
      end

      it "calls Decline use case" do
        use_case.call
        expect(TimeOffs::Decline).to have_received(:call).with(time_off)
      end

      it "doen't call Approve use case" do
        use_case.call
        expect(TimeOffs::Approve).not_to have_received(:call)
      end

      it "notifies observers" do
        use_case.call

        expect(observer).to have_received(:update)
          .with(notification_type: :time_off_declined, resource: time_off)
      end
    end
  end
end

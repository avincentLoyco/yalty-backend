# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimeOffs::Destroy do
  before do
    allow(TimeOffs::Decline).to receive(:call).and_call_original
  end

  let(:use_case) do
    described_class
      .new(time_off)
      .on(:success)      { :ok }
      .on(:not_modified) { :not_modified }
  end

  let(:time_off) do
    # enable status change temporarily for factory to build
    TimeOff.aasm(:approval_status).state_machine.config.no_direct_assignment = false

    create(:time_off, approval_status: approval_status, start_time: start_time) do
      # and disable again
      TimeOff.aasm(:approval_status).state_machine.config.no_direct_assignment = true
    end
  end

  let(:start_time) { 1.day.ago }

  describe "#call" do
    context "notifications" do
      let(:time_off_notifications) { Notification.where(resource: time_off) }
      let(:approval_status) { :pending }

      before do
        create(:notification, resource: time_off)
      end

      it "clears notifications for time_off" do
        expect { use_case.call }.to change { time_off_notifications.count }.by(-1)
      end
    end

    context "when status was pending" do
      let(:approval_status) { :pending }

      it "destroys time off" do
        expect { use_case.call }.to change { TimeOff.exists?(time_off.id) }.from(true).to(false)
      end

      it "calls success callback" do
        expect(use_case.call).to eq :ok
      end

      it "calls Decline use case" do
        use_case.call
        expect(TimeOffs::Decline).to have_received(:call).with(time_off)
      end
    end

    context "when status was approved" do
      let(:approval_status) { :approved }

      before do
        allow(DestroyEmployeeBalance).to receive(:call)
      end

      context "when time-off has started" do
        it "calls error callback" do
          expect { use_case.call }.to raise_error AASM::InvalidTransition
        end
      end

      context "when time-off has not started" do
        let(:start_time) { 1.day.since }

        it "destroys time off" do
          expect { use_case.call }.to change { TimeOff.exists?(time_off.id) }.from(true).to(false)
        end

        it "calls success callback" do
          expect(use_case.call).to eq :ok
        end

        it "calls Decline use case" do
          use_case.call
          expect(TimeOffs::Decline).to have_received(:call).with(time_off)
        end
      end
    end

    context "when status was declined" do
      let(:approval_status) { :declined }

      it "destroys time off" do
        expect { use_case.call }.to change { TimeOff.exists?(time_off.id) }.from(true).to(false)
      end

      it "calls success callback" do
        expect(use_case.call).to eq :ok
      end

      it "calls Decline use case" do
        use_case.call
        expect(TimeOffs::Decline).to have_received(:call).with(time_off)
      end
    end
  end
end

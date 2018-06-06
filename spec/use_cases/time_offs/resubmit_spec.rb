# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimeOffs::Resubmit do
  before do
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

  let(:expected_time_off) do
    TimeOff.where(
      employee: time_off.employee,
      time_off_category: time_off.time_off_category,
      start_time: start_time,
      end_time: end_time,
    )
  end

  describe "#call" do
    it "calls success callback" do
      expect(use_case.call).to eq :ok
    end

    it "re-creates time-off" do
      expect { use_case.call }.to change { expected_time_off.exists? }.from(false).to(true)
    end

    it "has no balance" do
      use_case.call
      expect(expected_time_off.first.employee_balance).to be_nil
    end

    it "has pending status" do
      use_case.call
      expect(expected_time_off.first.approval_status).to eq("pending")
    end

    it "notifies observers" do
      use_case.call

      expect(observer).to have_received(:update)
        .with(notification_type: :time_off_request, resource: expected_time_off.first)
    end

    context "when time-off auto approved" do
      before do
        time_off.time_off_category.update_column(:auto_approved, true)
      end

      it "re-creates time-off" do
        expect { use_case.call }.to change { expected_time_off.exists? }.from(false).to(true)
      end

      it "has approved status" do
        use_case.call
        expect(expected_time_off.first.approval_status).to eq("approved")
      end

      it "notifies observers" do
        use_case.call

        expect(observer).to have_received(:update)
          .with(notification_type: :time_off_approved, resource: expected_time_off.first)
      end
    end
  end
end

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

  end
end

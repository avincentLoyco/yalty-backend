# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimeOffs::Create do
  before do
    allow(observer).to receive(:update)
  end

  let(:use_case) do
    described_class
      .new(attributes)
      .add_observers(observer)
      .on(:success) {|time_off| time_off }
  end

  let(:employee) do
    create(:employee, :with_time_off_policy, :with_presence_policy, account: account)
  end
  let(:employee_time_off_policy) { employee.employee_time_off_policies.first }
  let(:time_off_category) { employee_time_off_policy.time_off_policy.time_off_category }
  let(:account) { create(:account) }

  let(:attributes) do
    {
      start_time: start_time,
      end_time: end_time,
      employee: employee,
      time_off_category: time_off_category,
    }
  end
  let(:start_time) { Date.new(2018,1,1) + 3.days }
  let(:end_time) { start_time + 3.months }
  let(:observer) { double }

  describe "#call" do
    it "creates time off" do
      expect { use_case.call }
        .to change { TimeOff.where(employee: employee, time_off_category: time_off_category).count }
        .by(1)
    end

    it "calls success callback" do
      expect(use_case.call)
        .to have_attributes(
          employee: employee,
          time_off_category: time_off_category,
          start_time: start_time,
          end_time: end_time
        )
    end

    context "when time off category is not auto-approved" do
      it "notifies observers" do
        use_case.call do |time_off|
          expect(observer).to have_received(:update)
            .with(notification_type: :time_off_request, resource: time_off)
        end
      end
    end

    context "when time off category is auto-approved" do
      before do
        allow(CreateEmployeeBalance).to receive(:call)
        time_off_category.update(auto_approved: true)
      end

      let(:time_off) { use_case.call }

      it "calls approve use-case" do
        allow(TimeOffs::Approve).to receive(:call)

        expect(TimeOffs::Approve).to have_received(:call).with(time_off)
      end

      it "notifies observers" do
        expect(observer).to have_received(:update)
          .with(notification_type: :time_off_approved, resource: time_off)
      end
    end
  end
end

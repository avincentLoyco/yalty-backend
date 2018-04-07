require "rails_helper"

RSpec.describe DeleteTypeInPeriod, type: :service do
  let!(:employee)  { create(:employee, hired_at: Date.new(2015, 1, 1)) }
  let(:event_type) { "default" }

  let(:start_date) { Date.new(2015, 1, 1)}
  let(:end_date)   { Date.new(2018, 1, 1)}

  let(:period_to_delete) do
    class_double("UnemploymentPeriod", start_date: start_date, end_date: end_date)
  end

  before do
    events =
      [Date.new(2016, 1, 1), Date.new(2016, 6, 6), Date.new(2017, 7, 7)].map do |effective_at|
        create(:employee_event, employee: employee, effective_at: effective_at)
      end

    allow(FindInPeriod).to receive(:call) { events }
  end

  subject do
    described_class.call(
      period_to_delete: period_to_delete,
      event_type: event_type,
      employee: employee
    )
  end

  context "deletes found events" do
    it { expect { subject }.to change { employee.events.reload.count } }
  end

  context "when there are no events to delete" do
    before { allow(FindInPeriod).to receive(:call).and_return([]) }

    it { expect { subject }.not_to change { employee.events.reload.count } }
  end
end

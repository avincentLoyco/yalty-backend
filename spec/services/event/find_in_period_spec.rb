require "rails_helper"

RSpec.describe FindInPeriod, type: :service do

  # setup
  let(:account)          { employee.account }
  let!(:employee)        { create(:employee, hired_at: Date.new(2015, 1, 1)) }
  let!(:second_employee) { create(:employee, account: account, hired_at: Date.new(2015, 2, 2)) }
  # default service params
  let(:start_date)     { Date.new(2016, 6, 6) }
  let(:end_date)       { Date.new(2017, 6, 6) }
  let(:event_type)     { "default" }
  let(:employee_param) { employee }

  let(:period_to_search) do
    class_double("UnemploymentPeriod", start_date: start_date, end_date: end_date)
  end

  before do
    Account.current = account

    first_employee_events_effective_ats =
      [Date.new(2016, 1, 1), Date.new(2016, 7, 1), Date.new(2017, 1, 1), Date.new(2017, 6, 7)]

    second_employee_events_effective_ats =
      [Date.new(2016, 6, 6), Date.new(2016, 7, 1), Date.new(2017, 1, 1), Date.new(2017, 6, 6)]

    first_employee_events_effective_ats.each do |effective_at|
      create(:employee_event,
        event_type: "default", effective_at: effective_at, employee: employee)
    end

    second_employee_events_effective_ats.each do |effective_at|
      create(:employee_event,
        event_type: "default", effective_at: effective_at, employee: second_employee)
    end
    employee.events.reload
    second_employee.events.reload
  end

  subject do
    described_class.call(
      period_to_search: period_to_search,
      event_type: event_type,
      employee: employee_param
    )
  end

  context "with only start_date param" do
    let(:end_date)       { Float::INFINITY }
    let(:event_type)     { nil }
    let(:employee_param) { nil }

    it "returns all account events from given date till infinity" do
      expect(subject.count).to eq(6)
    end
  end

  context "with multiple params specified" do
    context "without period end specified" do
      let(:end_date) { Float::INFINITY }

      it "returns given event_type events for employee from given date till infinity" do
        expect(subject.count).to eq(3)
      end
    end

    context "without event_type specified" do
      let(:event_type) { nil }

      it "returns all events for employee in given period" do
        expect(subject.count).to eq(2)
      end
    end

    context "without employee specified" do
      let(:employee_param) { nil }

      it "returns event_type events for account in given period" do
        expect(subject.count).to eq(4)
      end
    end
  end

  context "with all params specified" do
    it "returns given event_type events in period for selected employee" do
      expect(subject.count).to eq(2)
    end
  end

  context "without required start_date" do
    let(:start_date) { nil }
    it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
  end
end

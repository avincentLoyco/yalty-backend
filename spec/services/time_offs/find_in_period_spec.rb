require "rails_helper"

RSpec.describe TimeOffs::FindInPeriod, type: :service do

  # setup
  let(:account)          { employee.account }
  let!(:employee)        { create(:employee, hired_at: Date.new(2015, 1, 1)) }
  let!(:second_employee) { create(:employee, account: account, hired_at: Date.new(2015, 2, 2)) }

  let(:first_time_off_category_id)  { account.time_off_categories.first.id }
  let(:second_time_off_category_id) { account.time_off_categories.second.id }

  # default service params
  let(:start_time)           { Date.new(2016, 6, 6) }
  let(:end_time)             { Date.new(2017, 6, 6) }
  let(:time_off_category_id) { first_time_off_category_id }
  let(:employee_param)       { employee }

  let(:period_to_search) do
    class_double("UnemploymentPeriod", start_date: start_time, end_date: end_time)
  end

  before do
    Account.current = account

    first_employee_time_off_start_times =
      [Date.new(2016, 1, 1), Date.new(2016, 7, 1), Date.new(2017, 1, 1), Date.new(2017, 6, 7)]

    second_employee_time_off_start_times =
      [Date.new(2016, 6, 6), Date.new(2016, 7, 1), Date.new(2017, 1, 1), Date.new(2017, 6, 6)]

    first_employee_time_off_start_times.each do |start_time|
      create(:time_off,
        start_time: start_time,
        end_time: start_time + 5.days,
        employee: employee,
        time_off_category_id: first_time_off_category_id)
    end

    second_employee_time_off_start_times.each do |start_time|
      create(:time_off,
        start_time: start_time,
        end_time: start_time + 5.days,
        employee: second_employee,
        time_off_category_id: first_time_off_category_id)
    end

    create(:time_off,
      start_time: Date.new(2016, 6, 12),
      end_time: Date.new(2016, 6, 18),
      employee: employee,
      time_off_category_id: second_time_off_category_id)

    employee.time_offs.reload
    second_employee.time_offs.reload
  end

  subject do
    described_class.call(
      period_to_search: period_to_search,
      time_off_category_id: time_off_category_id,
      employee: employee_param
    )
  end

  context "with only start_time param" do
    let(:end_time)             { Float::INFINITY }
    let(:time_off_category_id) { nil }
    let(:employee_param)       { nil }

    it "returns all account time offs from given date till infinity" do
      expect(subject.count).to eq(7)
    end
  end

  context "with multiple params specified" do
    context "without end_time specified" do
      let(:end_time) { Float::INFINITY }

      it "returns given category time offs for employee from given date till infinity" do
        expect(subject.count).to eq(4)
      end
    end

    context "without category specified" do
      let(:time_off_category_id) { nil }

      it "returns all time offs for employee in given period" do
        expect(subject.count).to eq(3)
      end
    end

    context "without employee specified" do
      let(:employee_param) { nil }

      it "returns category time offs for account in given period" do
        expect(subject.count).to eq(5)
      end
    end
  end

  context "with all params specified" do
    it "returns given category time offs in period for selected employee" do
      expect(subject.count).to eq(3)
    end
  end

  context "without required start_time" do
    let(:start_time) { nil }
    it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
  end
end

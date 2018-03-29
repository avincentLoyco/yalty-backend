require "rails_helper"

RSpec.describe EmployeePolicy::TimeOff::FindInPeriod, type: :service do
  # setup
  let(:account)          { employee.account }
  let!(:employee)        { create(:employee, hired_at: Date.new(2015, 1, 1)) }
  let!(:second_employee) { create(:employee, account: account, hired_at: Date.new(2015, 2, 2)) }

  let(:vacation)         { account.time_off_categories.find_by(name: "vacation") }
  let(:sickness)         { account.time_off_categories.find_by(name: "sickness") }
  let!(:time_off_policy) { create(:time_off_policy, time_off_category: vacation) }
  let!(:sickness_policy) { create(:time_off_policy, time_off_category: sickness) }

  # call params
  let(:start_date)           { Date.new(2016, 6, 6) }
  let(:end_date)             { Date.new(2017, 6, 6) }
  let(:employee_param)       { employee }
  let(:time_off_category_id) { vacation.id }

  # EmployeeTimeOffPolicies dates
  let(:etop_at_find_period_start)  { Date.new(2016, 6, 6) }
  let(:etop_in_find_period_middle) { [Date.new(2016, 7, 1), Date.new(2017, 1, 1)] }
  let(:etop_at_find_period_end)    { Date.new(2017, 6, 6) }

  let(:second_etop_date_in_period) { Date.new(2016, 6, 7) }

  let(:period_to_search) do
    class_double("UnemploymentPeriod", start_date: start_date, end_date: end_date)
  end

  before do
    Account.current = account
    etop_dates =
      [etop_at_find_period_start, etop_in_find_period_middle, etop_at_find_period_end].flatten

    etop_dates.each do |date|
      create(:employee_time_off_policy,
        employee: employee,
        time_off_policy: time_off_policy,
        effective_at: date)
    end

    create(:employee_time_off_policy,
      employee: employee,
      time_off_policy: sickness_policy,
      effective_at: second_etop_date_in_period)

    etop_dates.each do |date|
      create(:employee_time_off_policy,
        employee: second_employee,
        time_off_policy: time_off_policy,
        effective_at: date)
    end
  end

  subject do
    described_class.call(
      period_to_search: period_to_search,
      parent_table_id: time_off_category_id,
      employee: employee_param
    )
  end

  context "with all params" do
    it "finds all vacation employee_time_off_policies in period for employee" do
      expect(subject.count).to eq(2)
    end

    context "with sickness as time_off_category" do
      let(:time_off_category_id) { sickness.id }

      it "finds all sickness employee_time_off_policies in period for employee" do
        expect(subject.count).to eq(1)
      end
    end
  end

  context "without time_off_category specified" do
    let(:time_off_category_id) { nil }

    it "finds all employee_time_off_policies in period" do
      expect(subject.count).to eq(3)
    end
  end

  context "without employee specified" do
    let(:employee_param) { nil }

    it "finds all vacation employee_time_off_policies in period" do
      expect(subject.count).to eq(4)
    end
  end

  context "without period end specified" do
    let(:end_date) { Float::INFINITY }

    it "finds all vacation employee_time_off_policies for employee from start_date" do
      expect(subject.count).to eq(3)
    end
  end

  context "without all params specified" do
    let(:end_date)             { Float::INFINITY }
    let(:employee_param)       { nil }
    let(:time_off_category_id) { nil }

    it "finds all employee_time_off_policies from start_date" do
      expect(subject.count).to eq(7)
    end
  end

  context "without required start_date" do
    let(:start_date) { nil }
    it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
  end
end

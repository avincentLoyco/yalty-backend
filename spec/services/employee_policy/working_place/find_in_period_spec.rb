require "rails_helper"

RSpec.describe EmployeePolicy::WorkingPlace::FindInPeriod, type: :service do
  # setup
  let(:account)          { employee.account }
  let!(:employee)        { create(:employee, hired_at: Date.new(2015, 1, 1)) }
  let!(:second_employee) { create(:employee, account: account, hired_at: Date.new(2015, 2, 2)) }

  let!(:working_place)        { create(:working_place, name: "first_wp", account: account) }
  let!(:second_working_place) { create(:working_place, name: "second_wp", account: account) }
  # call params
  let(:start_date)       { Date.new(2016, 6, 6) }
  let(:end_date)         { Date.new(2017, 6, 6) }
  let(:employee_param)   { employee }
  let(:working_place_id) { working_place.id }

  # EmployeeWorkingPlace dates
  let(:ewp_at_find_period_start)  { Date.new(2016, 6, 6) }
  let(:ewp_in_find_period_middle) { [Date.new(2016, 7, 1), Date.new(2017, 1, 1)] }
  let(:ewp_at_find_period_end)    { Date.new(2017, 6, 6) }

  let(:second_ewp_date_in_period) { Date.new(2016, 6, 7) }

  let(:period_to_search) do
    class_double("UnemploymentPeriod", start_date: start_date, end_date: end_date)
  end

  before do
    Account.current = account

    wp_dates =
      [ewp_at_find_period_start, ewp_in_find_period_middle, ewp_at_find_period_end].flatten

    wp_dates.each do |date|
      create(:employee_working_place,
        employee: employee,
        working_place: working_place,
        effective_at: date)
    end

    create(:employee_working_place,
      employee: employee,
      working_place: second_working_place,
      effective_at: second_ewp_date_in_period)

    wp_dates.each do |date|
      create(:employee_working_place,
        employee: second_employee,
        working_place: working_place,
        effective_at: date)
    end
  end

  subject do
    described_class.call(
      period_to_search: period_to_search,
      parent_table_id: working_place_id,
      employee: employee_param
    )
  end

  context "with all params" do
    it "finds all employee_working_places in period for employee" do
      expect(subject.count).to eq(2)
    end

    context "with different working_place_id" do
      let(:working_place_id) { second_working_place.id }

      it "finds all employee_working_places in period for employee" do
        expect(subject.count).to eq(1)
      end
    end
  end

  context "without time_off_category specified" do
    let(:working_place_id) { nil }

    it "finds all employee_working_places in period" do
      expect(subject.count).to eq(3)
    end
  end

  context "without employee specified" do
    let(:employee_param) { nil }

    it "finds all employee_working_places in period" do
      expect(subject.count).to eq(4)
    end
  end

  context "without end_date specified" do
    let(:end_date) { Float::INFINITY }

    it "finds all employee_working_places for employee from start_date" do
      expect(subject.count).to eq(3)
    end
  end

  context "without any filters" do
    let(:end_date)         { Float::INFINITY }
    let(:employee_param)   { nil }
    let(:working_place_id) { nil }

    it "finds all employee_working_places from start_date" do
      expect(subject.count).to eq(7)
    end
  end

  context "without required start_date" do
    let(:start_date) { nil }
    it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
  end
end

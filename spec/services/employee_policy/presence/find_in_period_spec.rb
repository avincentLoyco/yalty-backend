require "rails_helper"

RSpec.describe EmployeePolicy::Presence::FindInPeriod, type: :service do
  # setup
  let(:account)          { employee.account }
  let!(:employee)        { create(:employee, hired_at: Date.new(2015, 1, 1)) }
  let!(:second_employee) { create(:employee, account: account, hired_at: Date.new(2015, 2, 2)) }

  let!(:presence_policy)        { create(:presence_policy, :with_presence_day, account: account) }
  let!(:second_presence_policy) { create(:presence_policy, :with_presence_day, account: account) }

  let(:period_to_search) do
    class_double("UnemploymentPeriod", start_date: start_date, end_date: end_date)
  end

  # call params
  let(:start_date)         { Date.new(2016, 6, 6) }
  let(:end_date)           { Date.new(2017, 6, 6) }
  let(:employee_param)     { employee }
  let(:presence_policy_id) { presence_policy.id }

  # EmployeePresencePolicies dates
  let(:epp_at_find_period_start)  { Date.new(2016, 6, 6) }
  let(:epp_in_find_period_middle) { [Date.new(2016, 7, 1), Date.new(2017, 1, 1)] }
  let(:epp_at_find_period_end)    { Date.new(2017, 6, 6) }

  let(:second_epp_date_in_period) { Date.new(2016, 6, 7) }

  before do
    Account.current = account
    epp_dates =
      [epp_at_find_period_start, epp_in_find_period_middle, epp_at_find_period_end].flatten

    epp_dates.each do |date|
      create(:employee_presence_policy,
        employee: employee,
        presence_policy: presence_policy,
        effective_at: date)
    end

    create(:employee_presence_policy,
      employee: employee,
      presence_policy: second_presence_policy,
      effective_at: second_epp_date_in_period)

    epp_dates.each do |date|
      create(:employee_presence_policy,
        employee: second_employee,
        presence_policy: presence_policy,
        effective_at: date)
    end
  end

  subject do
    described_class.call(
      period_to_search: period_to_search,
      parent_table_id: presence_policy_id,
      employee: employee_param
    )
  end

  context "with all params" do
    it "finds all employee_presence_policies in period for employee" do
      expect(subject.count).to eq(2)
    end

    context "with different presence_policy_id" do
      let(:presence_policy_id) { second_presence_policy.id }

      it "finds all employee_presence_policies in period for employee" do
        expect(subject.count).to eq(1)
      end
    end
  end

  context "without presence_policy_id specified" do
    let(:presence_policy_id) { nil }

    it "finds all employee_presence_policies in period" do
      expect(subject.count).to eq(3)
    end
  end

  context "without employee specified" do
    let(:employee_param) { nil }

    it "finds all vacation employee_presence_policies in period" do
      expect(subject.count).to eq(4)
    end
  end

  context "without end_date specified" do
    let(:end_date) { Float::INFINITY }

    it "finds all vacation employee_presence_policies for employee from start_date" do
      expect(subject.count).to eq(3)
    end
  end

  context "without any filter" do
    let(:end_date)           { Float::INFINITY }
    let(:employee_param)     { nil }
    let(:presence_policy_id) { nil }

    it "finds all employee_presence_policies from start_date" do
      expect(subject.count).to eq(7)
    end
  end

  context "without required start_date" do
    let(:start_date) { nil }
    it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
  end
end

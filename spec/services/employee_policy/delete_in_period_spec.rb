require "rails_helper"

RSpec.describe EmployeePolicy::DeleteInPeriod, type: :service do
  before do
    allow(EmployeePolicy::WorkingPlace::FindInPeriod).to receive(:call) do
      [employee_working_place]
    end
    allow(EmployeePolicy::Presence::FindInPeriod).to receive(:call) do
      [employee_presence_policy]
    end
    allow(EmployeePolicy::TimeOff::FindInPeriod).to receive(:call) do
      [employee_time_off_policy]
    end
  end

  let!(:employee) { create(:employee) }

  # params
  let(:start_date)     { Date.new(2016, 6, 6) }
  let(:end_date)       { Date.new(2017, 6, 6) }
  let(:join_table_types) do
    %w(employee_working_places employee_presence_policies employee_time_off_policies)
  end

  let!(:employee_presence_policy) do
    create(:employee_presence_policy, employee: employee, effective_at: Date.new(2016, 6, 9))
  end

  let!(:employee_working_place) do
    create(:employee_working_place, employee: employee, effective_at: Date.new(2017, 6, 3))
  end

  let!(:employee_time_off_policy) do
    create(:employee_time_off_policy, employee: employee, effective_at: Date.new(2017, 1, 9))
  end

  let(:period_to_delete) do
    class_double("UnemploymentPeriod", start_date: start_date, end_date: end_date)
  end

  subject do
    described_class.call(
      period_to_delete: period_to_delete,
      join_table_types: join_table_types,
      employee: employee
    )
  end

  context "when no join table type is passed" do
    let(:join_table_types) { [] }
    it { expect(subject).to eq([]) }
  end

  context "when one join table type is passed" do
    context "when employee_working_places" do
      let(:join_table_types) { ["employee_working_places"] }
      it { expect(subject).to eq([employee_working_place]) }
    end

    context "when employee_presence_policies" do
      let(:join_table_types) { ["employee_presence_policies"] }
      it { expect(subject).to eq([employee_presence_policy]) }
    end

    context "when employee_time_off_policies" do
      let(:join_table_types) { ["employee_time_off_policies"] }
      it { expect(subject).to eq([employee_time_off_policy]) }
    end
  end

  context "when multiple join table types are passed" do
    it do
      expect(subject).to eq([employee_working_place,
                             employee_presence_policy,
                             employee_time_off_policy])
    end

    context "when two join table types specified" do
      let(:join_table_types) { %w(employee_working_places employee_presence_policies) }
      it { expect(subject).to eq([employee_working_place, employee_presence_policy]) }
    end
  end
end

require "rails_helper"

RSpec.describe Adjustments::Calculate, type: :service do
  include_context "shared_context_timecop_helper"

  before do
    allow(Employee::Event).to receive(:find) { event }
    allow(Employee).to receive(:find)        { employee }

    allow(Adjustments::Calculator::Hired).to receive(:call)        { 1 }
    allow(Adjustments::Calculator::WorkContract).to receive(:call) { 2 }
    allow(Adjustments::Calculator::ContractEnd).to receive(:call)  { 3 }
  end

  let!(:vacation_category) { employee.account.time_off_categories.find_by(name: "vacation") }
  let!(:time_off_policy) { create(:time_off_policy, time_off_category: vacation_category) }
  let!(:presence_policy) do
    create(:presence_policy, :with_time_entries, account: employee.account,
           standard_day_duration: 9600, default_full_time: true)
  end

  let(:employee) { create(:employee) }
  let(:employee_presence_policy) do
    create(:employee_presence_policy, presence_policy: presence_policy, employee: employee,
           effective_at: event.effective_at)
  end
  let(:event) do
    create(:employee_event, event_type: event_type, employee: employee, effective_at: 1.week.since)
  end
  let(:employee_time_off_policy) do
    create(:employee_time_off_policy, employee: employee, effective_at: event.effective_at,
           time_off_category: vacation_category)
  end

  subject { described_class.call(event.id) }


  context "hired" do
    before do
      employee.events.delete_all
      event.employee_time_off_policy = employee_time_off_policy
    end
    let(:event_type) { "hired" }

    it { expect(subject).to eq(9600) }
  end

  context "work_contract" do
    before do
      employee.events.delete_all
      hired_event = create(:employee_event, event_type: "hired", employee: employee,
        effective_at: Date.today)
      hired_event.employee_time_off_policy = create(:employee_time_off_policy, employee: employee,
        effective_at: Date.today, time_off_policy: time_off_policy)
      event.employee_time_off_policy = create(:employee_time_off_policy, employee: employee,
        effective_at: event.effective_at, time_off_policy: time_off_policy)
      employee.events << hired_event
      employee.events << event
    end

    let(:event_type) { "work_contract" }

    it { expect(subject).to eq(9600 * 2) }
  end

  context "contract_end" do
    before do
      event.employee_time_off_policy = employee_time_off_policy
    end
    let(:event_type) { "contract_end" }

    it { expect(subject).to eq(9600 * 3) }
  end
end

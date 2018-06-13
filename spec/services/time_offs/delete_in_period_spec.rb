require "rails_helper"

RSpec.describe TimeOffs::DeleteInPeriod, type: :service do
  let!(:employee)            { create(:employee, hired_at: Date.new(2015, 1, 1)) }
  let(:time_off_category)    { employee.account.time_off_categories.find_by(name: "vacation") }
  let(:time_off_category_id) { time_off_category.id }
  let(:period_start_date)    { Date.new(2015, 1, 1)}
  let(:period_end_date)      { Date.new(2018, 1, 1)}

  let(:period_to_delete) do
    class_double("UnemploymentPeriod", start_date: period_start_date, end_date: period_end_date)
  end

  before do
    travel_to Date.new(2015, 1, 1)
    time_offs =
      [Date.new(2016, 1, 1), Date.new(2016, 6, 6), Date.new(2017, 7, 7)].map do |start_time|
        create(:time_off,
          start_time: start_time,
          end_time: start_time + 5.days,
          employee: employee,
          time_off_category: time_off_category)
      end
    allow(TimeOffs::FindInPeriod).to receive(:call) { time_offs }
    TimeOffs::Approve.call(time_offs.first)
    time_offs.first.reload
  end

  after { travel_back }

  subject do
    described_class.call(
      period_to_delete: period_to_delete,
      time_off_category_id: time_off_category_id,
      employee: employee
    )
  end

  context "deletes found time offs and their balances" do
    it { expect { subject }.to change { employee.time_offs.reload.count } }
    it { expect { subject }.to change { employee.employee_balances.reload.count } }
  end

  context "when there are no time offs to delete" do
    before { allow(TimeOffs::FindInPeriod).to receive(:call).and_return([]) }

    it { expect { subject }.not_to change { employee.time_offs.reload.count } }
    it { expect { subject }.not_to change { employee.employee_balances.reload.count } }
  end
end

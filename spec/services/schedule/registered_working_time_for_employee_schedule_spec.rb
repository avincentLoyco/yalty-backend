require "rails_helper"

RSpec.describe RegisteredWorkingTimeForEmployeeSchedule, type: :service do
  include_context "shared_context_account_helper"

  describe ".call" do
    subject { described_class.new(employee_id, start_date, end_date).call }
    let(:employee) { create(:employee) }
    let(:employee_id) { employee.id }
    let(:start_date) { Date.new(2015, 1, 1) }
    let(:end_date) { Date.new(2015, 1, 3) }

    context "when there are time entries in day range" do
      let!(:first_working_time) do
        create(:registered_working_time, employee: employee, date: "1/1/2015")
      end
      let!(:second_working_time) do
        create(:registered_working_time, employee: employee, date: "2/1/2015")
      end
      let!(:empty_working_time) do
        create(:registered_working_time, employee: employee, date: "3/1/2015", time_entries: [])
      end

      context "range equal one day" do
        let(:start_date) { Date.new(2015, 1, 1) }
        let(:end_date) { Date.new(2015, 1, 3) }

        it { expect(subject.size).to eq 3 }
        it "returns valid hash" do
          expect(subject).to match_hash(
            {
              "2015-01-01" => [
                {
                  :type => "working_time",
                  :start_time => "10:00:00",
                  :end_time => "14:00:00",
                },
                {
                  :type => "working_time",
                  :start_time => "15:00:00",
                  :end_time => "20:00:00",
                },
              ],
              "2015-01-02" => [
                {
                  :type => "working_time",
                  :start_time => "10:00:00",
                  :end_time => "14:00:00",
                },
                {
                  :type => "working_time",
                  :start_time => "15:00:00",
                  :end_time => "20:00:00",
                },
              ],
              "2015-01-03" => [{}],
            }
          )
        end
      end

      context "range is longer than one day" do
        it { expect(subject.size).to eq 3 }
        it "returns valid hash" do
          expect(subject).to match_hash(
            {
              "2015-01-01" => [
                {
                  :type => "working_time",
                  :start_time => "10:00:00",
                  :end_time => "14:00:00",
                },
                {
                  :type => "working_time",
                  :start_time => "15:00:00",
                  :end_time => "20:00:00",
                },
              ],
              "2015-01-02" => [
                {
                  :type => "working_time",
                  :start_time => "10:00:00",
                  :end_time => "14:00:00",
                },
                {
                  :type => "working_time",
                  :start_time => "15:00:00",
                  :end_time => "20:00:00",
                },
              ],
              "2015-01-03" => [],
            }
          )
        end
      end
    end

    context "when there are no time entries in day range" do
      it { expect(subject.size).to eq 3 }
      it "returns valid hash" do
        expect(subject).to match_hash(
          {
            "2015-01-01" => [],
            "2015-01-02" => [],
            "2015-01-03" => [],
          }
        )
      end
    end
  end
end

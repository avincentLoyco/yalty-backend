require "rails_helper"

RSpec.describe HolidaysForEmployeeSchedule, type: :service do
  include_context "shared_context_account_helper"

  before do
    employee.first_employee_event.update!(effective_at: "1/1/2015")
  end

  let(:employee) { create(:employee) }
  let(:policy) { create(:holiday_policy, country: "ch", region: "zh") }

  subject { described_class.new(employee, range_start, range_end).call }

  context "with working place" do
    before "create employee working place" do
      working_place =
        create(:working_place, account: employee.account, holiday_policy: policy)
      create(
        :employee_working_place,
        working_place: working_place,
        employee: employee,
        effective_at: "1/1/2015",
      )
    end

    context "when employee has holidays in given range" do
      let(:range_start) { Date.new(2015, 12, 24) }
      let(:range_end) { Date.new(2016, 1, 1) }

      context "when all holidays have names" do
        it { expect(subject.size).to eq 9 }
        it "should have valid format" do
          expect(subject).to match_hash(
            {
              "2015-12-24" => [],
              "2015-12-25" => [
                {
                  :type=>"holiday",
                  :name=>"christmas"
                }
              ],
              "2015-12-26" => [
                {
                  :type=>"holiday",
                  :name=>"st_stephens_day"
                }
              ],
              "2015-12-27" => [],
              "2015-12-28" => [],
              "2015-12-29" => [],
              "2015-12-30" => [],
              "2015-12-31" => [],
              "2016-01-01" => [
                {
                  :type=>"holiday",
                  :name=>"new_years_day"
                }
              ],
            }
          )
        end
      end
    end
    context "when employee does not have holodays in given range" do
      let(:range_start) { Date.new(2015, 2, 2) }
      let(:range_end) { Date.new(2015, 2, 5) }

      it { expect(subject.size).to eq 4 }
      it "should have valid format" do
        expect(subject).to match_hash(
          {
            "2015-02-02" => [],
            "2015-02-03" => [],
            "2015-02-04" => [],
            "2015-02-05" => [],
          }
        )
      end
    end
  end

  context "without working place" do
    context "when there should be holidays in range" do
      let(:range_start) { Date.new(2015, 12, 24) }
      let(:range_end) { Date.new(2016, 1, 1) }

      it { expect(employee.employee_working_places.size).to eq 0 }
      it { expect(subject.size).to eq 9 }
      it "returns only registered working times" do
        expect(subject).to match_hash(
          {
            "2015-12-24" => [],
            "2015-12-25" => [],
            "2015-12-26" => [],
            "2015-12-27" => [],
            "2015-12-28" => [],
            "2015-12-29" => [],
            "2015-12-30" => [],
            "2015-12-31" => [],
            "2016-01-01" => [],
          }
        )
      end
    end
  end
end

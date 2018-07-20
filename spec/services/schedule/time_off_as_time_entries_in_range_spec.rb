require "rails_helper"

RSpec.describe TimeOffAsTimeEntriesForRange, type: :service do
  include_context "shared_context_timecop_helper"

  subject { described_class.new(start_date, end_date, time_off).call }
  let(:start_date) { Time.zone.now  - 1.hour }
  let(:end_date) { Time.zone.now + 2.days + 12.hours }
  let(:time_off) { create(:time_off, start_time: Time.zone.now + 5.hours, end_time: end_time) }
  let(:category_name) { time_off.time_off_category.name }

  context "when is for only one employee" do
    subject { described_class.new(start_date, end_date, time_off, false).call }
    context "when time off is shorter than one day" do
      let(:end_time) { Time.zone.now + 19.hours }

      it { expect(subject.size).to eq 1 }
      it "should have valid format" do
        expect(subject).to match_hash(
          {
            "2016-01-01" => [
              {
                type: "time_off_pending",
                name: category_name,
                start_time: "05:00:00",
                end_time: "19:00:00",
              },
            ],
          }
        )
      end
    end

    context "when time off is longer than day but shorter than two" do
      let(:end_time) { Time.zone.now + 2.days }

      it { expect(subject.size).to eq 2 }
      it "should have valid format" do
        expect(subject).to match_hash(
          {
            "2016-01-01" => [
              {
                type: "time_off_pending",
                name: category_name,
                start_time: "05:00:00",
                end_time: "24:00:00",
              },
            ],
            "2016-01-02" => [
              {
                type: "time_off_pending",
                name: category_name,
                start_time: "00:00:00",
                end_time: "24:00:00",
              },
            ],
          }
        )
      end
    end

    context "when time off is longer than two days" do
      let(:end_time) { Time.zone.now + 4.days + 19.hours }

      it { expect(subject.size).to eq 3 }
      it "should have valid format" do
        expect(subject).to match_hash(
          {
            "2016-01-03" => [
              {
                type: "time_off_pending",
                name: category_name,
                start_time: "00:00:00",
                end_time: "12:00:00",
              },
            ],
            "2016-01-01" => [
              {
                start_time: "05:00:00",
                end_time: "24:00:00",
                type: "time_off_pending",
                name: category_name,
              },
            ],
            "2016-01-02" => [
              {
                start_time: "00:00:00",
                end_time: "24:00:00",
                type: "time_off_pending",
                name: category_name,
              },
            ],
          }
        )
      end
    end
  end

  context "when is for many employees" do
    let(:employee_id) { time_off.employee_id}
    subject { described_class.new(start_date, end_date, time_off, true).call }
    context "when time off is shorter than one day" do
      let(:end_time) { Time.zone.now + 19.hours }

      it { expect(subject.size).to eq 1 }
      it "should have valid format" do
        expect(subject).to match_hash(
          {
            "2016-01-01" => {
              employee_id =>
                [
                  {
                    type: "time_off_pending",
                    name: category_name,
                    start_time: "05:00:00",
                    end_time: "19:00:00",
                  },
                ],
            },
          }
        )
      end
    end

    context "when time off is longer than day but shorter than two" do
      let(:end_time) { Time.zone.now + 2.days }

      it { expect(subject.size).to eq 2 }
      it "should have valid format" do
        expect(subject).to match_hash(
          {
            "2016-01-01" => {
              employee_id =>
                [
                  {
                    type: "time_off_pending",
                    name: category_name,
                    start_time: "05:00:00",
                    end_time: "24:00:00",
                  },
                ],
            },
            "2016-01-02" => {
              employee_id =>
                [
                  {
                    type: "time_off_pending",
                    name: category_name,
                    start_time: "00:00:00",
                    end_time: "24:00:00",
                  },
                ],
            },
          }
        )
      end
    end

    context "when time off is longer than two days" do
      let(:end_time) { Time.zone.now + 4.days + 19.hours }

      it { expect(subject.size).to eq 3 }
      it "should have valid format" do
        expect(subject).to match_hash(
          {
            "2016-01-01" => {
              employee_id =>
                [
                  {
                    type: "time_off_pending",
                    name: category_name,
                    start_time: "05:00:00",
                    end_time: "24:00:00",
                  },
                ],
            },
            "2016-01-02" => {
              employee_id =>
                [
                  {
                    type: "time_off_pending",
                    name: category_name,
                    start_time: "00:00:00",
                    end_time: "24:00:00",
                  },
                ],
            },
            "2016-01-03" => {
              employee_id =>
                [
                  {
                    type: "time_off_pending",
                    name: category_name,
                    start_time: "00:00:00",
                    end_time: "12:00:00",
                  },
                ],
            },
          }
        )
      end
    end
  end
end

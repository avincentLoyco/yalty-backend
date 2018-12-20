require "rails_helper"

RSpec.describe RegisteredWorkingTimes::CreateOrUpdate do
  describe "#call" do
    subject do
      described_class.new(
        part_of_employment_period_validator: part_of_employment_period_validator_mock,
      ).call(
        registered_working_time: registered_working_time,
        employee: employee,
        params: params
      )
    end

    let(:employee) { build(:employee) }
    let(:today) { Date.today }
    let(:yesterday) { Date.yesterday }
    let(:params) do
      {
        date: today,
        comment: "comment",
        time_entries: [
          {
            start_time: "11:00",
            end_time: "12:00",
          },
          {
            start_time: "13:00",
            end_time: "14:00",
          },
          {
            start_time: "15:00",
            end_time: "16:00",
          },
        ],
      }
    end

    let(:created_registered_working_time) do
      create(:registered_working_time,
        date: yesterday,
        time_entries: [
          {
            start_time: "11:00",
            end_time: "12:00",
          },
        ],
        comment: nil,
      )
    end

    let(:part_of_employment_period_validator_mock) do
      instance_double(RegisteredWorkingTimes::PartOfEmploymentPeriodValidator, call: true)
    end

    context "when registered working time is a new record" do
      let(:registered_working_time) { build(:registered_working_time) }
      let!(:registered_working_times_count) { RegisteredWorkingTime.count }

      context "when validation fails" do
        before do
          allow(part_of_employment_period_validator_mock)
            .to receive(:call).with(employee: employee, date: today).and_raise(StandardError)
        end

        it "doesn't create new record" do
          expect { subject }.to raise_error StandardError
          expect(part_of_employment_period_validator_mock).to have_received(:call)
          expect(RegisteredWorkingTime.count).to eq registered_working_times_count
        end
      end

      context "when validation pasess" do
        it "creates new record" do
          expect { subject }.to change { RegisteredWorkingTime.count }.by(1)
          expect(part_of_employment_period_validator_mock).to have_received(:call)
        end
      end
    end

    context "when registered working time is already existing record" do
      let!(:registered_working_time) { created_registered_working_time }
      let!(:registered_working_times_count) { RegisteredWorkingTime.count }

      context "when validation fails" do
        before do
          allow(part_of_employment_period_validator_mock)
            .to receive(:call).with(employee: employee, date: today).and_raise(StandardError)
        end

        it "registered working time is not updated" do
          expect { subject }.to raise_error StandardError
          expect(part_of_employment_period_validator_mock).to have_received(:call)
          expect(registered_working_time.date).to eq yesterday
        end
      end

      context "when validation pasess" do
        it "updates the record" do
          expect { subject }
            .to change { registered_working_time.time_entries.count }.from(1).to(3)
          expect(registered_working_time.date).to eq today
          expect(registered_working_time.comment.blank?).to eq false
          expect(part_of_employment_period_validator_mock).to have_received(:call)
        end
      end
    end
  end
end

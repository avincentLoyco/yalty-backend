require "rails_helper"

RSpec.describe RegisteredWorkingTimes::VerifyPartOfEmploymentPeriod do
  describe "#call" do
    subject do
      described_class.new.call(
        employee: employee,
        date: date,
      )
    end

    let!(:employee) { create(:employee) }
    let(:date) { today }

    let(:today) { Date.today }
    let(:tomorrow) { today + 1 }
    let(:events) { employee.events }

    context "when employee has only hired event" do
      it "returns true" do
        expect(subject).to eq true
      end
    end

    context "when employee has contract end added" do
      before do
        employee.events << contract_end_event
      end
      let(:contract_end_event) do
        create(:employee_event, event_type: "contract_end", employee: employee, effective_at: today)
      end

      context "when date is the same as the contract end" do
        it "returns true" do
          expect(subject).to eq true
        end
      end

      context "when date is one day after the contract end" do
        let(:date) { tomorrow }
        it "returns false" do
          expect(subject).to eq false
        end
      end
    end
  end
end

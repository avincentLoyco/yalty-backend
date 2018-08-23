require "rails_helper"

RSpec.describe Export::Employee::MaritalStatus, type: :service do
  subject { described_class.call(employee_events) }

  let(:employee_events) { [marriage, divorce, death] }

  let(:marriage) { { "event_type" => "marriage", "effective_at" => married_date } }
  let(:divorce)  { { "event_type" => "divorce", "effective_at" => divorce_date } }
  let(:death)    { { "event_type" => "spouse_death", "effective_at" => death_date } }

  let(:married_date) { "2016-06-06" }
  let(:divorce_date) { "2017-06-06" }
  let(:death_date)   { "2015-06-06" }

  context "when all marital events are present" do
    context "when divorce is latest event" do
      it { expect(subject).to eq("divorced") }
    end

    context "when marriage is latest event" do
      let(:married_date) { "2017-06-07" }

      it { expect(subject).to eq("married") }
    end

    context "when spouse_death is latest event" do
      let(:death_date) { "2017-06-07"  }

      it { expect(subject).to eq("single") }
    end
  end

  context "when only one event is present" do
    context "divorce" do
      let(:employee_events) { [divorce] }

      it { expect(subject).to eq("divorced") }
    end

    context "marriage" do
      let(:employee_events) { [marriage] }

      it { expect(subject).to eq("married") }
    end

    context "spouse_death" do
      let(:employee_events) { [death] }

      it { expect(subject).to eq("single") }
    end
  end

  context "without marital events" do
    let(:employee_events) { [] }

    it { expect(subject).to eq("single") }
  end
end

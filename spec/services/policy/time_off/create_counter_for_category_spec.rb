require "rails_helper"

RSpec.describe Policy::TimeOff::CreateCounterForCategory do
  before do
    allow(TimeOffCategory).to receive(:find) { time_off_category }
  end

  subject { described_class.call(time_off_category) }

  let(:time_off_category) { create(:time_off_category, name: "University Days") }

  it { expect(subject.name).to eq(time_off_category.name) }
  it { expect(subject.policy_type).to eq("counter")}
end

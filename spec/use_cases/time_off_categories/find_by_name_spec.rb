require "rails_helper"

RSpec.describe TimeOffCategories::FindByName do
  describe "#call" do
    subject { described_class.new(account_model: account_model_mock).call(category) }

    let(:category)     { "vacation" }
    let(:account)      { build(:account) }
    let(:vacation_toc) { build(:time_off_category) }

    let(:account_model_mock) do
      class_double(Account, current: account)
    end

    before do
      allow(account.time_off_categories).to receive(:find_by).and_return(vacation_toc)
      subject
    end

    it { expect(account.time_off_categories).to have_received(:find_by).with(name: "vacation") }
    it { expect(subject).to eq(vacation_toc) }
  end
end

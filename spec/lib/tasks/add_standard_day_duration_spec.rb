require "rails_helper"
require "rake"

RSpec.describe "add_standard_day_duration", type: :rake do
  include_context "rake"

  let(:presence_day) { build(:presence_day, minutes: 1400) }
  let(:policy) { create(:presence_policy, presence_days: [presence_day]) }

  shared_examples "omitting update" do
    it "omits update" do
      expect(policy).to_not receive(:update!)
      subject
    end
  end

  context "updates standard_day_duration" do
    before { policy.update_column(:standard_day_duration, nil) }

    it { expect { subject }.to change { policy.reload.standard_day_duration }.from(nil).to(1400) }
  end

  context "policy already with standard_day_duration set" do
    it_behaves_like "omitting update"
  end

  context "reset policy" do
    before { policy.update_column(:reset, true) }

    it_behaves_like "omitting update"
  end

  context "policy without presence_days" do
    before { policy.presence_days.delete_all }

    it_behaves_like "omitting update"
  end
end

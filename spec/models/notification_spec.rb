require "rails_helper"

RSpec.describe Notification, type: :model do
  subject(:notification) { build(:notification) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:resource) }

  describe "#type" do
    subject { notification.notification_type }

    before do
      notification.notification_type = "notification_type"
    end

    it { is_expected.to eq("notification_type") }
  end

  context "scopes" do
    describe ".unread" do
      before do
        create(:notification)
        create(:notification, seen: true)
      end

      it "returns only unread notifications" do
        expect(described_class.unread.count).to eq 1
      end
    end
  end
end

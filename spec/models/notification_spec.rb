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

      let!(:notifications) do
        [
          create(:notification, created_at: Time.current - 1.day),
          create(:notification, created_at: Time.current - 3.days),
          create(:notification, created_at: Time.current - 2.days),
          create(:notification, seen: true),
        ]
      end

      it "returns only unread and sorted notifications" do
        expect(described_class.unread).to eq(
          [
            notifications[0],
            notifications[2],
            notifications[1],
          ]
        )
      end
    end
  end
end

require "rails_helper"

RSpec.describe EmailDispatcher do
  let(:dispatcher) { described_class.new }

  class FakeNotificationMailer
    class << self
      def message(recipient, resource)
        new(recipient, resource)
      end
    end

    pattr_initialize :recipient, :resource

    def deliver_later
      { recipient: recipient, resource: resource }
    end
  end

  describe "#update" do
    before do
      dispatcher.notification_mailer = notification_mailer
      allow(Notifications::Recipient)
        .to receive(:call).with(notification_type, :resource).and_return(recipient)
    end

    let(:send_notification) do
      dispatcher.update(notification_type: notification_type, resource: :resource)
    end

    let(:notification_mailer) { FakeNotificationMailer }

    let(:notification_type) { "message" }

    let(:recipient) { :user }

    it "calls proper method on NotificationMailer" do
      expect(send_notification).to include(recipient: :user, resource: :resource)
    end

    context "when notification type is not supported" do
      let(:notification_type) { "other" }

      it { expect { send_notification }.to raise_error described_class::UnsupportedNotificationType}
    end

    context "when recipient is not present" do
      let(:recipient) { nil }

      it "doesn't call mailer" do
        expect(send_notification).to be_nil
      end
    end
  end
end

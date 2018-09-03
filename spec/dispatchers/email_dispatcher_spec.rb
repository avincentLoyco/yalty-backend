require "rails_helper"

RSpec.describe EmailDispatcher do
  class FakeMailer
    def self.message(_recipient, _resource); end
  end

  let(:dispatcher) { described_class.new }

  let(:delivery) { instance_double("FakeDelivery", deliver_later: true) }

  describe "#update" do
    before do
      allow(FakeMailer).to receive(:message).and_return(delivery)
      dispatcher.notification_mailer = FakeMailer
      allow(Notifications::Recipient)
        .to receive(:call).with(notification_type, :resource).and_return(recipients)
    end

    let(:send_notification) do
      dispatcher.update(notification_type: notification_type, resource: :resource)
    end

    let(:notification_type) { "message" }

    let(:recipients) { %i(user) }

    it "calls proper method on NotificationMailer" do
      send_notification
      expect(FakeMailer).to have_received(:message).with(:user, :resource)
      expect(delivery).to have_received(:deliver_later)
    end

    context "when notification type is not supported" do
      let(:notification_type) { "other" }

      it { expect { send_notification }.to raise_error described_class::UnsupportedNotificationType}
    end

    context "when recipients are not present" do
      let(:recipients) { [] }

      it "doesn't call mailer" do
        send_notification
        expect(FakeMailer).not_to have_received(:message)
        expect(delivery).not_to have_received(:deliver_later)
      end
    end
  end
end

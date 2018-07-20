require "rails_helper"

RSpec.describe InternalDispatcher do
  let_it_be(:dispatcher) { described_class.new }

  let_it_be(:employee) { create(:employee) }

  let_it_be(:resource) { create(:time_off, employee: employee) }

  let_it_be(:manager) { create(:account_user) }

  let_it_be(:user) { create(:account_user) }

  let(:dispatch) do
    dispatcher.update(notification_type: notification_type, resource: resource)
  end

  let(:notifications) do
    Notification.where(
      notification_type: notification_type,
      user: recipient,
      resource: resource,
    )
  end

  before do
    allow(resource).to receive(:manager).and_return(manager)
    allow(employee).to receive(:user).and_return(user)
  end

  describe "time_off_request" do
    let(:notification_type) { "time_off_request" }
    let(:recipient) { manager }

    it "create notification for time-off manager" do
      expect { dispatch } .to change { notifications.count }.by(1)
    end

    context "when manager was not set" do
      let(:manager) { nil }

      it "doesn't create notification" do
        expect { dispatch } .not_to change { Notification.count }
      end
    end
  end

  describe "time_off_approved" do
    let(:notification_type) { "time_off_approved" }
    let(:recipient) { user }

    it "create notification for employee" do
      expect { dispatch } .to change { notifications.count }.by(1)
    end

    context "when employee has no user" do
      let(:user) { nil }

      it "doesn't create notification" do
        expect { dispatch } .not_to change { Notification.count }
      end
    end
  end

  describe "time_off_declined" do
    let(:notification_type) { "time_off_declined" }
    let(:recipient) { user }

    it "create notification for employee" do
      expect { dispatch } .to change { notifications.count }.by(1)
    end

    context "when employee has no user" do
      let(:user) { nil }

      it "doesn't create notification" do
        expect { dispatch } .not_to change { Notification.count }
      end
    end
  end

  describe "unknown_notification_type" do
    let(:notification_type) { "unknown_notification_type" }

    it "doesn't create notification" do
      expect { dispatch } .not_to change { Notification.count }
    end
  end
end

require "rails_helper"

RSpec.describe "Mark notification as seen", :auth_user, type: :request do
  let_it_be(:auth_user) { create(:account_user) }
  let(:notification_user) { auth_user }
  let(:notification) { create(:notification, user: notification_user) }

  let(:params) { {} }

  subject(:request) do
    put(api_v1_notification_read_path(notification), params, headers) && response
  end

  context "when reading own notification" do
    it { is_expected.to have_http_status(:success) }

    it "updates notification read status" do
      expect { request }.to change { notification.reload.seen? }.from(false).to(true)
    end
  end

  context "when notification doesn't exist" do
    before do
      notification.destroy
    end

    it { is_expected.to have_http_status(:not_found) }
  end

  context "when reading other user notification" do
    let(:notification_user) { create(:account_user) }

    it { is_expected.to have_http_status(:not_found) }

    it "doesn't update notification read status" do
      expect { request }.not_to change { notification.reload }
    end
  end
end

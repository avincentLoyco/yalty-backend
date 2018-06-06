require "rails_helper"

RSpec.describe "List unread notifications", :auth_user, type: :request do
  let_it_be(:auth_user) { create(:account_user) }

  let(:params) { {} }

  subject(:request) do
    get(api_v1_notifications_path, params, headers) && response
  end

  it { is_expected.to have_http_status(:success) }

  context "when notifications exist" do
    before do
      create(:notification)
      create(:notification, user: auth_user, seen: true)
    end

    let!(:current_user_notification) do
      create(:notification, user: auth_user, resource: time_off)
    end

    let(:time_off) { build(:time_off) }

    it "has only unread notifications for current_user in the response body" do
      request
      expect(json_body).to contain_exactly(
        {
          notification_type: "time_off_request",
          resource_type: "TimeOff",
          resource_id: time_off.id,
          user_id: auth_user.id,
          id: current_user_notification.id,
          type: "notification",
        }
      )
    end
  end
end

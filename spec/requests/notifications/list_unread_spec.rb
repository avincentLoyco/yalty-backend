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

    let(:time_off) { create(:time_off) }

    it "has only unread notifications for current_user in the response body" do
      request
      expect(json_body).to contain_exactly(
        {
          notification_type: "time_off_request",
          user_id: auth_user.id,
          id: current_user_notification.id,
          type: "notification",
          resource: {
            id: time_off.id,
            type: "time_off",
            start_time: time_off.start_time.as_json,
            end_time: time_off.end_time.as_json,
            approval_status: "pending",
            employee: {
              id: time_off.employee.id,
              type: "employee",
              fullname: time_off.employee.fullname,
              account_user_id: nil,
            },
          },
        }
      )
    end
  end
end

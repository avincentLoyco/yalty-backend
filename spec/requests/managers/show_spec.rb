require "rails_helper"

RSpec.describe "Show manager", type: :request do
  describe "GET /managers/:id", :auth_user do
    subject(:get_manager) do
      get(api_v1_manager_path(manager_id),{}, headers) && response
    end

    let_it_be(:account) { create(:account) }

    let_it_be(:employee) do
      create(:employee, :with_attributes, account: account)
    end

    let_it_be(:auth_user) { create(:account_user, employee: employee, account: account) }

    let(:manager_id) { employee.account_user_id }

    it { is_expected.to have_http_status(:success) }

    it "has correct response body" do
      get_manager

      expect(json_body).to eq(
        {
          id: employee.id,
          type: "employee",
          fullname: employee.fullname,
          account_user_id: employee.account_user_id,
        }
      )
    end
  end
end

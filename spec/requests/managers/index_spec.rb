require "rails_helper"

RSpec.describe "List managers", type: :request do
  describe "GET /managers", :auth_user do
    subject(:get_managers) do
      get("/v1/managers",{}, headers) && response
    end

    let_it_be(:account) { create(:account) }

    let_it_be(:employee) do
      create(:employee, :with_attributes, account: account)
    end

    let_it_be(:other_employee) do
      create(:employee, :with_attributes, account: account)
    end

    let_it_be(:auth_user) { create(:account_user, employee: employee, account: account) }

    let_it_be(:other_user) { create(:account_user, employee: other_employee, account: account) }

    let_it_be(:employee_without_user) { create(:employee, account: account) }

    let_it_be(:yalty_access_user) { create(:account_user, :with_yalty_role, account: account) }

    it { expect(get_managers).to have_http_status(:success) }

    it "has correct response body" do
      get_managers

      expect(json_body).to contain_exactly(
        {
          id: employee.id,
          type: "employee",
          fullname: employee.fullname,
          account_user_id: employee.account_user_id,
        },
        {
          id: other_employee.id,
          type: "employee",
          fullname: other_employee.fullname,
          account_user_id: other_employee.account_user_id,
        }
      )
    end
  end
end

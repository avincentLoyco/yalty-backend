require "rails_helper"

RSpec.describe "Employee balance", type: :request do
  let_it_be(:account_user) { create(:account_user, role: "account_owner") }
  let_it_be(:token) { create(:account_user_token, resource_owner_id: account_user.id).token }
  let_it_be(:vacation_category) { account_user.account.time_off_categories.vacation.first }
  let_it_be(:vacation_policy) { create(:time_off_policy, time_off_category: vacation_category) }

  let_it_be(:employee) { account_user.employee }

  let(:headers) do
    { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
  end

  let(:params) { {} }

  before_all do
    create(:employee_time_off_policy, employee: employee, time_off_policy: vacation_policy)
  end

  shared_examples "filterable" do
    before do
      allow(BalanceOverview::Generate).to receive(:call).and_call_original
      request
    end

    context "when no category filter passed" do
      it "passes employee only" do
        expect(BalanceOverview::Generate).to have_received(:call).with(employee, {})
      end
    end

    context "when category filter passed" do
      let(:params) { { category: "vacation" } }

      it "passes employee and category" do
        expect(BalanceOverview::Generate)
          .to have_received(:call).with(employee, category: "vacation")
      end
    end

    context "when date filter passed" do
      let(:params) { { date: "2018-01-01" } }

      it "passes employee and category" do
        expect(BalanceOverview::Generate)
          .to have_received(:call).with(employee, date: Date.new(2018, 1, 1))
      end
    end

    context "when invalid date passed" do
      let(:params) { { date: "something" } }

      it { is_expected.to have_http_status(:unprocessable_entity) }

      it "has errors in ther response body" do
        expect_json_keys("errors.*", %i(field messages status type codes employee_id))
        expect(json_body[:errors]).to include(hash_including(field: "date"))
      end
    end
  end

  describe "GET /employees/:employee_id/employee_balance_overview" do

    subject(:request) do
      get(api_v1_employee_employee_balance_overview_path(employee.id), params, headers) && response
    end

    context "when accesing own data" do
      it { is_expected.to have_http_status(:success) }

      it_behaves_like "filterable"

      it "has correct response body" do
        request
        expect(json_body).to contain_exactly(
          {
            category: "vacation",
            employee: employee.id,
            result: 0,
          }
        )
      end
    end

    context "when user is not authenticated" do
      let(:headers) {{}}

      it { is_expected.to have_http_status(:unauthorized) }

      it "has errors in ther response body" do
        request
        expect_json_keys("errors.*", %i(field messages status type codes employee_id))
      end
    end

    context "when accessing other employee data" do
      let(:employee) { create(:employee) }

      it { is_expected.to have_http_status(:not_found) }

      it "has errors in ther response body" do
        request
        expect_json_keys("errors.*", %i(field messages type codes))
      end
    end
  end

  describe "GET /employee_balance_overview" do

    subject(:request) do
      get(api_v1_employee_balance_overview_path, params, headers) && response
    end

    it { is_expected.to have_http_status(:success) }

    it_behaves_like "filterable"

    context "when user is not authenticated" do
      let(:headers) {{}}

      it { is_expected.to have_http_status(:unauthorized) }

      it "has errors in ther response body" do
        request
        expect_json_keys("errors.*", %i(field messages status type codes employee_id))
      end
    end

    context "when multiple employees hired" do
      let_it_be(:employee_2) { create(:employee, account: account_user.account) }

      before_all do
        create(:employee_time_off_policy, employee: employee_2, time_off_policy: vacation_policy)
      end

      it "has balances for both employees" do
        request
        expect(json_body).to contain_exactly(
          {
            category: "vacation",
            employee: employee.id,
            result: 0,
          },
          {
            category: "vacation",
            employee: employee_2.id,
            result: 0,
          }
        )
      end
    end
  end
end

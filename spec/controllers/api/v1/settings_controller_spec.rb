require "rails_helper"

RSpec.describe API::V1::SettingsController, type: :controller do
  include_examples "example_authorization",
    resource_name: "account"
  include_context "shared_context_headers"

  let!(:presence_policy) do
    create(:presence_policy, :with_time_entries, account: account, occupation_rate: 0.8)
  end

  describe "GET #show" do
    subject { get :show }

    it { is_expected.to have_http_status(200) }

    context "response body" do
      before { subject }

      it { expect_json(
          id: account.id,
          type: "account",
          company_name: account.company_name,
          subdomain: account.subdomain,
          yalty_access: account.yalty_access,
          available_modules: account.available_modules.data.map(&:id),
          default_locale: account.default_locale,
          timezone: account.timezone
        )
      }
    end
  end

  describe "without user GET #show" do
    before(:each) do
      Account::User.current = nil
    end

    it "should return company name and locale when is account" do
      get :show
      data = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(data).to include("company_name")
      expect(data).to include("default_locale")
      expect(data).to_not include("available_modules")
      expect(data).to_not include("subdomain")
      expect(data).to_not include("id")
      expect(data).to_not include("yalty_access")
      expect(data["company_name"]).to eq(Account.current.company_name)
    end

    it "should return 401 when account is not present" do
      Account.current = nil

      get :show
      expect(response).to have_http_status(401)
    end
  end

  describe "PUT #update" do
    let(:company_name) { "My Company" }
    let(:yalty_access) { false }
    let(:timezone) { "Europe/Madrid" }
    let(:subdomain) { Account.current.subdomain }

    let(:settings_json) do
      {
        type: "settings",
        company_name: company_name,
        subdomain: subdomain,
        yalty_access: yalty_access,
        timezone: timezone,
        default_locale: "en",
      }
    end

    subject { put :update, settings_json }

    context "with valid data" do
      it { expect { subject }.to change { account.reload.company_name } }

      it { is_expected.to have_http_status(204) }

      context "with zurich timezone" do
        let(:timezone) { "Europe/Zurich" }

        it { expect { subject }.to change { account.reload.timezone }.to("Europe/Zurich") }

        it { is_expected.to have_http_status(204) }
      end

      context "subdomain" do
        context "when subdomain does not change" do
          it { expect { subject }.to_not change { Account.current.reload.subdomain } }

          it { is_expected. to have_http_status(204) }
        end

        context "when subdomain change" do
          let(:redirect_uri) { "http://yalty.test/setup"}
          let(:client) { FactoryGirl.create(:oauth_client, redirect_uri: redirect_uri) }
          let(:subdomain) { "new-subdomain" }

          before(:each) do
            ENV["YALTY_OAUTH_ID"] = client.uid
            ENV["YALTY_OAUTH_SECRET"] = client.secret
          end

          it { expect { subject }.to change { Account.current.reload.subdomain } }
          it { is_expected. to have_http_status(301) }

          context "response" do
            before { subject }

            it { expect_json(redirect_uri: regex("^http://#{subdomain}.yalty.test/setup")) }
          end
        end

        context "when yalty access is enable" do
          let(:yalty_access) { true }

          it { expect { subject }.to change { Account.current.yalty_access } }

          it { is_expected. to have_http_status(204) }
        end

        context "when yalty access is disable" do
          let(:yalty_access) { false }

          before { Account.current.update!(yalty_access: true) }

          it { expect { subject }.to change { Account.current.yalty_access } }

          it { is_expected. to have_http_status(204) }
        end
      end
    end

    context "with invalid data" do
      context "with invalid timezone" do
        let(:timezone) { "abc" }

        it { expect { subject }.to_not change { account.reload.company_name } }

        it { is_expected.to have_http_status(422) }
      end

      context "with missing params" do
        let(:missing_params_json) { settings_json.tap { |attr| attr.delete(:company_name) } }
        subject { put :update, missing_params_json }

        it { expect { subject }.to_not change { account.reload.company_name } }

        it { is_expected.to have_http_status(422) }
      end
    end
  end
end

require "rails_helper"

RSpec.describe "Tokens", type: :request do
  let(:host) { "http://launchpad.yalty.lvh.me:3000" }
  let(:redirect_uri) { host + "/setup" }
  let(:token_request_url) { host + "/oauth/accounts/token" }
  let(:client) { FactoryGirl.create(:oauth_client, redirect_uri: redirect_uri) }
  let(:oath_code) { FactoryGirl.create(:oauth_code, application: client) }
  let(:token) { oath_code.token }

  before(:each) do
    ENV["YALTY_OAUTH_ID"] = client.uid
    ENV["YALTY_OAUTH_SECRET"] = client.secret
    ENV["YALTY_OAUTH_REDIRECT_URI"] = client.redirect_uri
    ENV["YALTY_OAUTH_SCOPES"] = client.scopes.to_s
  end

  describe "create auth token with auth code" do
    subject(:get_token) do
      get(token_request_url, code: token) && response
    end

    let(:expected_response) do
      {
        access_token: String,
        token_type: "Bearer",
        expires_in: Integer,
        refresh_token: String,
        created_at: Integer,
        user: hash_including(:id, :role, :type, :employee),
      }
    end

    it { is_expected.to have_http_status(:success) }

    it "should create token" do
      expect { get_token }.to change { client.access_tokens.count }.by(1)
    end

    it "has correct response body" do
      get_token
      expect(json_body).to include(**expected_response)
    end

    context "when wrong code" do
      let(:token) { "wrong" }

      it "should return error" do
        expect(get_token).to have_http_status(:unauthorized)
        expect_json_keys [:error, :error_description]
      end
    end

    context "when re-used code" do
      before do
        get("http://launchpad.yalty.lvh.me:3000/oauth/accounts/token", code: token)
      end

      it "should return error" do
        expect(get_token).to have_http_status(:unauthorized)
        expect_json_keys [:error, :error_description]
      end
    end
  end
end

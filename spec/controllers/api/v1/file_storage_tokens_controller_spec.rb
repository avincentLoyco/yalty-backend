require "rails_helper"

RSpec.describe API::V1::FileStorageTokensController, type: :controller do
  include_context "shared_context_headers"
  include_context "shared_context_timecop_helper"

  subject(:request_token) { post :create, params }
  before { allow(SecureRandom).to receive(:hex).and_return("1234567887654321") }

  describe "for upload" do
    let(:params) {{}}
    before { request_token }

    it { expect(response.status).to eq(201) }
    it "return proper json" do
      expect_json(
        token: "generic_file_1234567887654321",
        file_id: GenericFile.last.id,
        type: "token",
        created_at: Time.zone.now.to_s,
        expires_at: (Time.zone.now + 30.seconds).to_s,
        counter: 1,
        action_type: "upload"
      )
    end
  end

  describe "for download" do
    let(:generic_file) { create(:generic_file, :with_pdf) }
    let(:long_token_allowed) { false }
    let(:attribute_definition) do
      create(:employee_attribute_definition, :required, attribute_type: "File", name: "contract",
        long_token_allowed: long_token_allowed)
    end
    let(:employee_attribute) do
      create(:employee_attribute, account: account, attribute_type: "File",
        attribute_definition: attribute_definition,
        data: { size: 1000, file_type: "application/pdf", id: generic_file.id, original_sha: "12" })
    end

    context "return proper json" do
      let(:params) {{ file_id: generic_file.id }}

      before do
        employee_attribute
        request_token
      end

      it { expect(response.status).to eq(201) }
      it "return proper json" do
        expect_json(
          token: "generic_file_1234567887654321",
          file_id: generic_file.id,
          type: "token",
          created_at: Time.zone.now.to_s,
          expires_at: (Time.zone.now + 30.seconds).to_s,
          counter: 1,
          action_type: "download"
        )
      end
    end

    context "version" do
      let(:params) {{ file_id: generic_file.id, version: "thumbnail" }}

      context "if sent and exists" do
        let!(:generic_file) { create(:generic_file, :with_jpg).reload }

        before do
          employee_attribute
          request_token
        end

        it { expect(response.status).to eq(201) }
      end

      context "if sent and exists" do
        let(:generic_file) { create(:generic_file, :with_pdf) }

        before do
          employee_attribute
          request_token
        end

        it { expect(response.status).to eq(422) }
      end
    end

    context "token lifetime" do
      context "shortterm" do
        let(:long_token_allowed) { false }
        before { employee_attribute }

        context "is default" do
          let(:params) {{ file_id: generic_file.id }}
          let(:expires_at) { JSON.parse(response.body)["expires_at"] }

          before { request_token }

          it { expect(expires_at).to eq((Time.zone.now + 30.seconds).to_s) }
        end

        context "fails when longterm param sent" do
          let(:params) {{ file_id: generic_file.id, duration: "longterm" }}
          let(:expected_response) do
            {
              "type" => "file_storage_tokens",
              "field" => "duration",
              "messages" => ["Requested longterm token when not allowed"],
              "codes" => ["duration.requested_longterm_token_when_not_allowed"],
            }
          end

          before { request_token }

          it { expect(JSON.parse(response.body)["errors"].first).to eq(expected_response) }
          it { expect(response.status).to eq(422) }
        end
      end

      context "longterm" do
        let(:long_token_allowed) { true }
        before { employee_attribute }

        context "is valid for 12h" do
          let(:params) {{ file_id: generic_file.id, duration: "longterm" }}
          let(:expires_at) { JSON.parse(response.body)["expires_at"] }

          before { request_token }

          it { expect(expires_at).to eq((Time.zone.now + 12.hours).to_s) }
        end

        context "returns shortterm if asked in payload" do
          let(:params) {{ file_id: generic_file.id, duration: "shortterm" }}
          let(:expires_at) { JSON.parse(response.body)["expires_at"] }

          before { request_token }

          it { expect(expires_at).to eq((Time.zone.now + 30.seconds).to_s) }
        end
      end
    end

    context ".file_not_found!" do
      let(:params) {{ file_id: "123abc-random" }}
      let(:expected_response) do
        {
          "type" => nil,
          "messages" => ["Record Not Found"],
          "field" => "id",
          "codes" => ["error_record_not_found"],
        }
      end

      before { request_token }

      it { expect(JSON.parse(response.body)["errors"].first).to eq(expected_response) }
    end
  end

  describe "authorization" do
    let(:account) { create(:account) }
    let(:user) { create(:account_user, account: account, employee: employee) }
    let!(:employee) { create(:employee, account: account) }

    let(:different_employee) { create(:employee, account: account) }
    let(:generic_file) { create(:generic_file, :with_jpg) }
    let(:attribute_definition) do
      create(:employee_attribute_definition, :required, attribute_type: "File",
        name: file_type, long_token_allowed: true)
    end
    let(:employee_attribute) do
      create(:employee_attribute, account: account, attribute_type: "File",
        attribute_definition: attribute_definition, employee: employee_for_file,
        data: { size: 1000, file_type: "image/jpeg", id: generic_file.id, original_sha: "12" })
    end

    before do
      Account::User.current = user
      Account.current = account
    end

    context "can request token for upload" do
      let(:params) { {} }
      before { request_token }

      it { expect(response.status).to eq(201) }
    end

    context "can request token for download every profile_picture" do
      let(:file_type) { "profile_picture" }
      let(:employee_for_file) { different_employee }
      let(:params) {{ file_id: generic_file.id }}

      before do
        employee_attribute
        request_token
      end

      it { expect(response.status).to eq(201) }
    end

    context "can't request download token for other users files" do
      let(:file_type) { "contract" }
      let(:employee_for_file) { different_employee }
      let(:params) { { file_id: generic_file.id } }

      before do
        employee_attribute
        employee.reload
        request_token
      end

      it { expect(response.status).to eq(403) }
    end

    context "can request token for download his files" do
      let(:file_type) { "contract" }
      let(:employee_for_file) { employee }
      let(:params) { { file_id: generic_file.id } }

      before do
        employee_attribute
        employee.reload
        request_token
      end

      it { expect(response.status).to eq(201) }
    end
  end
end

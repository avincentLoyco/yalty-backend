require 'rails_helper'

RSpec.describe API::V1::CompanyEventsController, type: :controller do
  include_context 'shared_context_headers'

  shared_examples 'sending email' do
    it { expect(CompanyEventsMailer).to have_received(:event_changed) }
  end

  shared_examples 'not sending email' do
    it { expect(CompanyEventsMailer).to_not have_received(:event_changed) }
  end

  let(:company_event) { create(:company_event, account: account) }
  let(:jpg_file) { create(:generic_file, :with_jpg) }
  let(:pdf_file) { create(:generic_file, :with_pdf) }

  before do
    ENV['YALTY_ACCESS_EMAIL'] = 'access@example.com'
    allow(CompanyEventsMailer).to receive_message_chain(:event_changed, :deliver_later)
  end

  context '#index GET /company_events' do
    let!(:company_event) { create(:company_event, :with_files, account: account) }

    subject(:get_index) { get(:index) }

    shared_examples 'successful request' do
      let(:user) { create(:account_user, account: account, role: role) }

      before { get_index }

      it { expect(response.status).to eq(200) }
      it { expect_json_sizes(1) }
      it { expect_json_keys('*', %i(title effective_at comment files)) }
    end

    context 'user has administrator role' do
      let(:role) { 'account_administrator' }

      it_behaves_like 'successful request'
    end

    context 'user has owner role' do
      let(:role) { 'account_owner' }

      it_behaves_like 'successful request'
    end

    context 'user has yalty role' do
      let(:user) do
        create(:account_user, :with_yalty_role, account: account, employee: nil,
          email: 'access@example.com')
      end

      it { is_expected.to have_http_status(200) }
    end

    context 'user is regular user' do
      let(:user) { create(:account_user, account: account, role: 'user') }

      it { is_expected.to have_http_status(403) }
    end
  end

  context '#show GET /company_events/:id' do
    subject(:get_show) { get(:show, { id: company_event.id }) }

    shared_examples 'successful request' do
      let(:user) { create(:account_user, account: account, role: role) }

      before { get_show }

      it { expect(response.status).to eq(200) }
      it { expect_json_keys(%i(title effective_at comment files)) }
    end

    context 'user has administrator role' do
      let(:role) { 'account_administrator' }

      it_behaves_like 'successful request'
    end

    context 'user has owner role' do
      let(:role) { 'account_owner' }

      it_behaves_like 'successful request'
    end

    context 'user has yalty role' do
      let(:user) do
        create(:account_user, account: account, role: 'yalty', employee: nil,
          email: 'access@example.com')
      end

      it { is_expected.to have_http_status(200) }
    end

    context 'user is regular user' do
      let(:user) { create(:account_user, account: account, role: 'user') }

      it { is_expected.to have_http_status(403) }
    end

    context 'with files' do
      let(:title) { 'Batman is Bruce Wayne' }
      let(:effective_at) { Date.today }
      let!(:company_event) do
        create(:company_event, title: title, effective_at: effective_at, account: account,
          files: [jpg_file, pdf_file], comment: nil)
      end

      let(:expected_json) do
        {
          title: title,
          effective_at: effective_at.strftime('%Y-%m-%d'),
          comment: nil
        }
      end

      let(:expected_files_json) do
        [
          {
            'type' => 'file',
            'id' => jpg_file.id,
            'original_filename' => 'test.jpg'
          },
          {
            'type' => 'file',
            'id' => pdf_file.id,
            'original_filename' => 'example.pdf'
          },
        ]
      end

      before { get_show }

      it { expect_json(expected_json) }
      it { expect(JSON.parse(response.body)["files"]).to match_array(expected_files_json) }
    end
  end

  context '#create POST /company_events' do
    let(:params) {{ title: 'New title', effective_at: Date.today }}

    subject(:post_create) { post(:create, params) }

    shared_examples 'successful request' do
      before { post_create }

      it { expect(response.status).to eq(200) }
      it { expect_json_keys(%i(title effective_at comment files)) }
      it_behaves_like 'sending email'
    end

    shared_examples 'not successful request' do
      before { post_create }

      it { expect(response.status).to eq(403) }
      it_behaves_like 'not sending email'
    end

    context 'module is active' do
      before do
        account.available_modules.add(id: 'companyevent')
        account.save!
      end

      it { expect { post_create }.to change(CompanyEvent, :count).by(1) }

      context 'user has administrator role' do
        let(:user) { create(:account_user, account: account, role: 'account_administrator') }

        it_behaves_like 'successful request'
      end

      context 'with files' do
        let(:created_event) { CompanyEvent.find(JSON.parse(response.body)['id']) }
        let(:params) {{ title: 'New title', effective_at: Date.today, files: files_params }}
        let(:files_params) do
          [
            { id: jpg_file.id, type: 'file', original_filename: jpg_file.original_filename },
            { id: pdf_file.id, type: 'file', original_filename: pdf_file.original_filename }
          ]
        end

        before { post_create }

        it { expect(response.status).to eq(200) }
        it { expect(created_event.files.count).to eq(2) }
        it { expect(created_event.file_ids).to match_array([jpg_file.id, pdf_file.id]) }
      end

      context 'when files and comment are nil' do
        let(:params) {{ title: 'New title', effective_at: Date.today, files: nil }}

        before { post_create }

        it { expect(response.status).to eq(200) }
      end

      context 'user has owner role' do
        let(:user) { create(:account_user, account: account, role: 'account_owner') }

        it_behaves_like 'successful request'
      end

      context 'user has yalty role' do
        let(:user) do
          create(:account_user, account: account, role: 'yalty', employee: nil,
            email: 'access@example.com')
        end

        it_behaves_like 'successful request'
      end

      context 'user is regular user' do
        let(:user) { create(:account_user, account: account, role: 'user') }

        it_behaves_like 'not successful request'
      end
    end

    context 'module is inactive' do
      before do
        account.available_modules.delete_paid
        account.save!
      end

      it { expect { post_create }.to_not change(CompanyEvent, :count) }

      context 'user has administrator role' do
        it_behaves_like 'not successful request'
      end

      context 'user has owner role' do
        let(:user) { create(:account_user, account: account, role: 'account_owner') }

        it_behaves_like 'not successful request'
      end

      context 'user has yalty role' do
        let(:user) do
          create(:account_user, account: account, role: 'yalty', employee: nil,
            email: 'access@example.com')
        end

        it_behaves_like 'not successful request'
      end

      context 'user is regular user' do
        let(:user) { create(:account_user, account: account, role: 'user') }

        it_behaves_like 'not successful request'
      end
    end
  end

  context '#update PUT /company_events/:id' do
    let(:title) { 'New title' }
    let(:date) { 2.days.from_now.to_date }
    let(:params) {{ id: company_event.id, title: title, effective_at: date }}

    subject(:put_update) { put(:update, params) }

    shared_examples 'successful request' do
      before { put_update }

      it { expect(response.status).to eq(200) }
      it { expect_json_keys(%i(title effective_at comment files)) }
      it_behaves_like 'sending email'
    end

    shared_examples 'not successful request' do
      before { put_update }

      it { expect(response.status).to eq(403) }
      it_behaves_like 'not sending email'
    end

    context 'module is active' do
      before do
        account.available_modules.add(id: 'companyevent')
        account.save!
      end

      it { expect { put_update }.to change { company_event.reload.title }.to(title) }
      it { expect { put_update }.to change { company_event.reload.effective_at }.to(date) }

      context 'user has administrator role' do
        it_behaves_like 'successful request'
      end

      context 'with files' do
        let(:params) do
          { id: company_event.id, title: 'Title', effective_at: Date.today, files: files_params }
        end
        let(:files_params) do
          [
            { id: jpg_file.id, type: 'file', original_filename: jpg_file.original_filename },
            { id: pdf_file.id, type: 'file', original_filename: pdf_file.original_filename }
          ]
        end

        before { put_update }

        it { expect(response.status).to eq(200) }
        it { expect(company_event.files.count).to eq(2) }
        it { expect(company_event.file_ids).to match_array([jpg_file.id, pdf_file.id]) }
      end

      context 'files and comment are nil' do
        let(:params) do
          { id: company_event.id, title: 'Title', effective_at: Date.today, files: nil }
        end

        before { put_update }

        it { expect(response.status).to eq(200) }
      end

      context 'user has owner role' do
        let(:user) { create(:account_user, account: account, role: 'account_owner') }

        it_behaves_like 'successful request'
      end

      context 'user has yalty role' do
        let(:user) do
          create(:account_user, account: account, role: 'yalty', employee: nil,
            email: 'access@example.com')
        end

        it_behaves_like 'successful request'
      end

      context 'user is regular user' do
        let(:user) { create(:account_user, account: account, role: 'user') }

        it_behaves_like 'not successful request'
      end
    end

    context 'module is inactive' do
      before do
        account.available_modules.delete_paid
        account.save!
      end

      context 'user has administrator role' do
        it_behaves_like 'not successful request'
      end

      context 'user has owner role' do
        let(:user) { create(:account_user, account: account, role: 'account_owner') }

        it_behaves_like 'not successful request'
      end

      context 'user has yalty role' do
        let(:user) do
          create(:account_user, account: account, role: 'yalty', employee: nil,
            email: 'access@example.com')
        end

        it_behaves_like 'not successful request'
      end

      context 'user is regular user' do
        let(:user) { create(:account_user, account: account, role: 'user') }

        it_behaves_like 'not successful request'
      end
    end
  end

  context '#destroy DELETE /company_events/:id' do
    subject(:delete_subject) { delete(:destroy, { id: company_event.id }) }

    shared_examples 'successful request' do
      before { delete_subject }

      it { expect(response.status).to eq(204) }
      it_behaves_like 'sending email'
    end

    shared_examples 'not successful request' do
      before { delete_subject }

      it { expect(response.status).to eq(403) }
      it_behaves_like 'not sending email'
    end

    context 'module is active' do
      before do
        account.available_modules.add(id: 'companyevent')
        account.save!
      end

      context 'removes company_event' do
        let!(:company_event) { create(:company_event, :with_files, account: account) }

        it { expect { delete_subject }.to change(CompanyEvent, :count).by(-1) }
      end

      context 'user has administrator role' do
        it_behaves_like 'successful request'
      end

      context 'user has owner role' do
        let(:user) { create(:account_user, account: account, role: 'account_owner') }

        it_behaves_like 'successful request'
      end

      context 'user has yalty role' do
        let(:user) do
          create(:account_user, account: account, role: 'yalty', employee: nil,
            email: 'access@example.com')
        end

        it_behaves_like 'successful request'
      end

      context 'user is regular user' do
        let(:user) { create(:account_user, account: account, role: 'user') }

        it_behaves_like 'not successful request'
      end
    end

    context 'module is inactive' do
      before do
        account.available_modules.delete_paid
        account.save!
      end

      context 'does not delete company_event' do
        let!(:company_event) { create(:company_event, :with_files, account: account) }

        it { expect { delete_subject }.to_not change(CompanyEvent, :count) }
      end

      context 'user has administrator role' do
        it_behaves_like 'not successful request'
      end

      context 'user has owner role' do
        let(:user) { create(:account_user, account: account, role: 'account_owner') }

        it_behaves_like 'not successful request'
      end

      context 'user has yalty role' do
        let(:user) do
          create(:account_user, account: account, role: 'yalty', employee: nil,
            email: 'access@example.com')
        end

        it_behaves_like 'not successful request'
      end

      context 'user is regular user' do
        let(:user) { create(:account_user, account: account, role: 'user') }

        it_behaves_like 'not successful request'
      end
    end
  end
end

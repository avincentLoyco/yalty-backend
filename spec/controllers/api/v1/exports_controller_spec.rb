require 'rails_helper'
require 'fakeredis/rspec'

RSpec.describe API::V1::ExportsController, type: :controller do
  include_context 'shared_context_headers'

  before do
    allow(::Export::CreateArchive).to receive(:perform_later).with(account) do
      account.update!(archive_processing: true)
    end
  end

  shared_examples 'archive is processing' do
    it { expect(response.status).to eq(202) }
    it { expect_json({ status: 'processing', file_id: nil, archive_date: nil }) }
  end

  context 'initialize archive' do
    before { post :create }

    it_behaves_like 'archive is processing'
  end

  context 'check status' do
    subject(:check_status) { get :show }

    context 'when archive is still processing' do
      before do
        account.update!(archive_processing: true)
        check_status
      end

      it_behaves_like 'archive is processing'
    end

    context 'when archive is complete' do
      let!(:archive_file) do
        create(:generic_file, fileable_id: account.id, fileable_type: 'Account')
      end

      let(:expected_json) do
        {
          status: 'complete',
          file_id: archive_file.id,
          archive_date: archive_file.created_at.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
        }
      end

      before { check_status }

      it { expect(response.status).to eq(200) }
      it { expect_json(expected_json) }
    end
  end
end

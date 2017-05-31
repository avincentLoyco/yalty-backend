require 'rails_helper'
require 'fakeredis/rspec'

RSpec.describe API::V1::ExportsController, type: :controller do
  include_context 'shared_context_headers'

  shared_examples 'archive is processing' do
    it { expect(account.archive_processing).to be(true) }
    it { expect(response.status).to eq(202) }
    it { expect_json({ status: 'processing', file_id: nil, archive_date: nil }) }
  end

  context 'initialize archive' do
    subject(:init_archive) { post :create }

    it 'updates account' do
      expect(account).to receive(:update!).with(archive_processing: true)
      init_archive
    end

    it 'schdules the archive job' do
      expect { init_archive }.to change { ActiveJob::Base.queue_adapter.enqueued_jobs.size }.by(1)
    end

    context 'response' do
      before { init_archive }

      it_behaves_like 'archive is processing'
    end
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

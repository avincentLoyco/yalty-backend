require "rails_helper"

RSpec.describe Export::ScheduleArchiveProcess, type: :job do
  let!(:account) { create(:account, archive_processing: true) }

  subject(:schedule_archive) { described_class.perform_now(account) }

  before do
    allow(::Export::CreateArchiveZip).to receive_message_chain(:new, :call)
    allow(ExportMailer).to receive_message_chain(:archive_generation, :deliver_now)
  end

  context "when success" do
    it "invokes CreateArchiveZip service" do
      expect(::Export::CreateArchiveZip).to receive_message_chain(:new, :call)
      schedule_archive
    end

    it "sends the archive email" do
      expect(ExportMailer).to receive_message_chain(:archive_generation, :deliver_now)
      schedule_archive
    end

    it "updates account.archive_processing status" do
      expect { schedule_archive }
        .to change { account.reload.archive_processing }
        .from(true)
        .to(false)
    end
  end
end

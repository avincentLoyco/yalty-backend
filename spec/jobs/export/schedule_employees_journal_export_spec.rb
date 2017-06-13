require 'rails_helper'

RSpec.describe Export::ScheduleEmployeesJournalExport, type: :job do
  let(:export_job) { ::Export::SendEmployeesJournal }
  let!(:account_with_yalty_access) { create(:account, yalty_access: true) }
  let!(:account_without_yalty_access) { create(:account, yalty_access: false) }

  subject(:schedule_exports) { described_class.new.perform }

  before do
    ENV['LOYCO_SSH_HOST'] = 'sftp.loyco.ch'
    ENV['LOYCO_SSH_USER'] = 'user'
    ENV['LOYCO_SSH_KEY_PATH'] = '/path/to/key'
  end

  it { expect(account_with_yalty_access.yalty_access).to be(true) }
  it { expect(account_without_yalty_access.yalty_access).to be(false) }

  it 'schedules export only once' do
    expect(export_job).to receive(:perform_later).once
    schedule_exports
  end

  it 'schedules export only for accounts with yalty special access' do
    expect(export_job).to receive(:perform_later).with(account_with_yalty_access)
    schedule_exports
  end

  it 'do not schedule job if SFTP is not configured' do
    expect(export_job).to_not receive(:perform_later)
    ENV['LOYCO_SSH_HOST'] = ''
    schedule_exports
  end
end

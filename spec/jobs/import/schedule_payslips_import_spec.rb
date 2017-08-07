require 'rails_helper'

RSpec.describe Import::SchedulePayslipsImport, type: :job do
  let(:import_payslips_job) { Import::ImportPayslipsJob }

  let!(:account) do
    account = build(:account)
    account.available_modules.add(id: 'automatedexport')
    account.save
    account
  end
  let!(:employee) { create(:employee, account: account) }

  let(:payslip_filename) { "#{employee.id}-01-01-2016.pdf" }
  let(:ssh_payslip_path) { File.join('/fake/path', payslip_filename) }
  let(:ssh_host) { 'fakehost' }
  let(:ssh_user) { 'fakeuser' }
  let(:ssh_path) { 'fakepath' }
  let(:sftp) do
    sftp = double('sftp')
    entry = double('entry')
    allow(entry).to receive(:name).and_return(ssh_payslip_path)
    allow(sftp).to receive_message_chain(:dir, :glob).and_yield(entry)
    sftp
  end

  before do
    ENV['LOYCO_SSH_HOST'] = ssh_host
    ENV['LOYCO_SSH_USER'] = ssh_user
    ENV['LOYCO_SSH_KEY_PATH'] = ssh_path

    allow(Net::SFTP).to receive(:start).with(ssh_host, ssh_user, keys: [ssh_path]).and_yield(sftp)
  end

  subject(:schedule_payslips_import) { described_class.new.perform }

  context 'when automatedexport module is enabled' do
    before { allow(::Import::ImportAndAssignPayslips).to receive(:enable?) { true } }

    it 'schedules import only once' do
      expect(import_payslips_job).to receive(:perform_later).with(ssh_payslip_path).once
      schedule_payslips_import
    end
  end

  context 'when automated export module is not enabled' do
    before { allow(::Import::ImportAndAssignPayslips).to receive(:enable?) { false } }

    it 'do not schedule import' do
      expect(import_payslips_job).to_not receive(:perform_later)
      schedule_payslips_import
    end
  end
end

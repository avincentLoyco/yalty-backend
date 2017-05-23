require 'rails_helper'

RSpec.describe Export::SendEmployeesJournal, type: :job do
  let!(:account) { create(:account) }
  let(:ssh_host) { 'fakehost' }
  let(:ssh_user) { 'fakeuser' }
  let(:ssh_path) { 'fakepath' }
  let(:filename) { Pathname.new('employees_journal.csv') }
  let(:path)     { Rails.root.join(filename) }

  subject(:generate_and_send_journal) { described_class.new.perform(account) }

  before do
    ENV['LOYCO_SSH_HOST'] = ssh_host
    ENV['LOYCO_SSH_USER'] = ssh_user
    ENV['LOYCO_SSH_KEY_PATH'] = ssh_path
    allow(::Export::GenerateEmployeesJournal).to receive_message_chain(:new, :call).and_return(path)
    allow(Net::SCP)
      .to receive(:upload!)
      .with(ssh_host, ssh_user, path.to_s, filename.to_s, ssh: { keys: [ssh_path] })
  end

  it 'invokes spreadsheet creator' do
    expect(::Export::GenerateEmployeesJournal).to receive_message_chain(:new, :call)
    generate_and_send_journal
  end

  it 'uploads journal to sftp server' do
    expect(Net::SCP)
      .to receive(:upload!)
      .with(ssh_host, ssh_user, path.to_s, filename.to_s, ssh: { keys: [ssh_path] })
    generate_and_send_journal
  end
end

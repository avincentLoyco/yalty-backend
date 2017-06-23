require 'rails_helper'

RSpec.describe Export::SendEmployeesJournal, type: :job do
  let!(:account) { create(:account) }
  let(:ssh_host) { 'fakehost' }
  let(:ssh_user) { 'fakeuser' }
  let(:ssh_path) { 'fakepath' }
  let(:filename) { Pathname.new('employees_journal.csv') }
  let(:path)     { Rails.root.join(filename) }
  let(:sftp) do
    sftp = double('sftp')
    allow(sftp).to receive(:upload!)
    sftp
  end

  subject(:generate_and_send_journal) { described_class.new.perform(account) }

  before do
    ENV['LOYCO_SSH_HOST'] = ssh_host
    ENV['LOYCO_SSH_USER'] = ssh_user
    ENV['LOYCO_SSH_KEY_PATH'] = ssh_path
    ENV['LOYCO_SSH_EXPORT_JOURNAL_PATH'] = '/'
    allow(::Export::GenerateEmployeesJournal).to receive_message_chain(:new, :call).and_return(path)
    allow(Net::SFTP)
      .to receive(:start)
      .with(ssh_host, ssh_user, keys: [ssh_path])
      .and_yield(sftp)
  end

  it 'invokes spreadsheet creator' do
    expect(::Export::GenerateEmployeesJournal).to receive_message_chain(:new, :call).with(
      account,
      account.last_employee_journal_export,
      an_instance_of(Time),
      an_instance_of(Pathname)
    ).with(any_args)
    generate_and_send_journal
  end

  it 'uploads journal to sftp server when exists' do
    expect(sftp).to receive(:upload!).with(path.to_s, "/#{filename.to_s}")
    generate_and_send_journal
  end

  it 'sets last_employee_journal_export date for account' do
    expect { generate_and_send_journal }.to change(account, :last_employee_journal_export)
  end

  it 'do not uploads journal to sftp server when not exists' do
    allow(::Export::GenerateEmployeesJournal).to receive_message_chain(:new, :call).and_return(nil)
    expect(sftp).to_not receive(:upload!)
    generate_and_send_journal
  end

  it 'do not perform job if SFTP is not configured' do
    expect(sftp).to_not receive(:upload!)
    ENV['LOYCO_SSH_HOST'] = ''
    generate_and_send_journal
  end
end

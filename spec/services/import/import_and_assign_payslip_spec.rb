require 'rails_helper'
RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe Import::ImportAndAssignPayslips do
  include_context 'shared_context_timecop_helper'

  let(:automatedexport) { Payments::PlanModule.new(id: 'automatedexport') }
  let(:account) { create(:account, available_modules: ::Payments::AvailableModules.new(data: [automatedexport])) }
  let!(:salary_slip_definition) { create(:employee_attribute_definition, account: account, name: 'salary_slip', multiple: false, attribute_type: 'File') }
  let(:employee) { create(:employee, account: account) }

  let(:ssh_host) { 'fakehost' }
  let(:ssh_user) { 'fakeuser' }
  let(:ssh_path) { 'fakepath' }

  let(:payslip_filename) { "#{employee.id}-01-01-2016.pdf" }
  let(:tmp_path) { Pathname.new('tmp').join('files') }
  let(:ssh_payslip_path) { tmp_path.join(ssh_path, payslip_filename) }
  let(:import_path) { tmp_path.join(payslip_filename) }
  let(:fixture_path) { Pathname.new('spec').join('fixtures', 'files', 'example.pdf') }

  let(:sftp) do
    sftp = double('sftp')
    allow(sftp).to receive_message_chain(:dir, :glob).and_yield(ssh_payslip_path)
    allow(sftp).to receive(:download!)
    allow(sftp).to receive(:remove!)
    sftp
  end

  subject(:assign_payslip) { described_class.new(employee, tmp_path).call }

  before do
    ENV['LOYCO_SSH_HOST'] = ssh_host
    ENV['LOYCO_SSH_USER'] = ssh_user
    ENV['LOYCO_SSH_KEY_PATH'] = ssh_path
    ENV['LOYCO_SSH_IMPORT_PAYSLIPS_PATH'] = ssh_path

    FileUtils.mkdir_p(tmp_path.join(ssh_path))
    FileUtils.copy_file(fixture_path, ssh_payslip_path)
    FileUtils.copy_file(fixture_path, import_path)

    allow(Net::SFTP).to receive(:start).with(ssh_host, ssh_user, keys: [ssh_path]).and_yield(sftp)
  end

  context 'salary_paid event does not exist' do
    it 'creates GenericFile, Employee::Event and Employee::AttributeVersion' do
      expect { assign_payslip }
        .to change(GenericFile, :count).by(1)
        .and change(Employee::Event, :count).by(1)
        .and change(Employee::AttributeVersion, :count).by(1)
    end

    it 'properly downloads and removes payslip from sftp' do
      expect(sftp).to receive_message_chain(:dir, :glob).with("**/#{payslip_filename}")
      expect(sftp).to receive(:download!).with(ssh_payslip_path, import_path)
      expect(sftp).to receive(:remove!).with(ssh_payslip_path)
      assign_payslip
    end
  end

  context 'salary_paid event already exists' do
    let(:existing_file) { create(:generic_file, :with_pdf) }

    let(:value) do
      {
        id: existing_file.id,
        file_type: existing_file.file_content_type,
        size: existing_file.file_file_size,
      }.merge(existing_file.sha_sums)
    end

    let(:version) do
      build(:employee_attribute_version, employee: employee, value: value, attribute_type: 'File')
    end

    let!(:existing_event) do
      create(:employee_event, event_type: 'salary_paid', employee: employee,
        employee_attribute_versions: [version], effective_at: Time.zone.now)
    end

    it 'only updates AttributeVersion with new pyslip data' do
      expect { assign_payslip }
        .to change(GenericFile, :count).by(1)
        .and not_change(Employee::Event, :count)
        .and not_change(Employee::AttributeVersion, :count)
    end
  end
end

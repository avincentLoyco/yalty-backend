require 'rails_helper'

RSpec.describe Import::SchedulePayslipsImport, type: :job do
  let(:import_payslips_job) { Import::ImportPayslipsJob }
  let!(:account_with_data_enabled) do
    account = build(:account)
    account.available_modules.add(id: 'automatedexport')
    account.save
    account
  end
  let!(:account_without_data_enabled) { create(:account) }
  subject(:schedule_payslips_import) { described_class.new.perform }

  context 'when automatedexport module not enabled' do
    before { allow(::Import::ImportAndAssignPayslips).to receive(:enable?) { true } }

    it 'schedules import only once' do
      expect(import_payslips_job).to receive(:perform_later).once
      schedule_payslips_import
    end

    it 'schedules export only for accounts with module enabled' do
      expect(import_payslips_job).to receive(:perform_later).with(account_with_data_enabled)
      schedule_payslips_import
    end
  end

  context 'when automated export module is enabled' do
    it 'do not schedule if module not enabled' do
      expect(import_payslips_job).to_not receive(:perform_later)
      schedule_payslips_import
    end
  end
end

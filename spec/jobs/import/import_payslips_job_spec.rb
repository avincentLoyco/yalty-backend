require "rails_helper"

RSpec.describe Import::ImportPayslipsJob, type: :job do
  let!(:account) do
    account = create(:account)
    account.available_modules.add(id: "automatedexport")
    account.save
    account
  end

  let!(:employee) { create(:employee, account: account) }

  let(:payslip_filename) { "20160101_#{employee.id}.pdf" }
  let(:payslip_date) { Date.parse("01-01-2016") }
  let(:ssh_payslip_path) { File.join("/fake/path", payslip_filename) }

  subject(:import_payslips) { described_class.new.perform(ssh_payslip_path) }

  before do
    allow(Import::ImportAndAssignPayslips).to receive_message_chain(:new, :call)
    allow(Import::ImportAndAssignPayslips).to receive(:enable?).and_return(true)
  end

  it "call import service" do
    expect(::Import::ImportAndAssignPayslips)
      .to receive_message_chain(:new, :call).with(employee, anything, payslip_date).with(no_args)
    import_payslips
  end
end

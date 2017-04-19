require 'rails_helper'
require 'rake'

RSpec.describe 'payments:create_missing_receipt_numbers', type: :rake do
  include_context 'rake'

  subject { rake['payments:create_missing_receipt_numbers'].invoke }

  context 'it should assign receipt_number to paid invoice' do
    let(:file) { create(:generic_file, :with_pdf) }
    let!(:paid_invoice) { create :invoice, status: 'success', generic_file: file }
    let!(:second_invoice) { create :invoice, status: 'success', generic_file: file }

    it { expect { subject }.to change { paid_invoice.reload.receipt_number } }
    it { expect { subject }.to change { second_invoice.reload.receipt_number } }

    context 'receipt_numbers are unique' do
      before { subject }

      it do
        expect(paid_invoice.reload.receipt_number).not_to eq(second_invoice.reload.receipt_number)
      end
    end
  end

  context 'it should not assign receipt_number to other invoices' do
    let!(:pending_invoice) { create :invoice }
    let!(:failed_invoice) { create :invoice, status: 'failed' }

    it { expect { subject }.not_to change { pending_invoice.reload.receipt_number } }
    it { expect { subject }.not_to change { failed_invoice.reload.receipt_number } }

    context 'receipt_numbers stay nil' do
      before { subject }

      it { expect(pending_invoice.reload.receipt_number).to eq(nil) }
      it { expect(failed_invoice.reload.receipt_number).to eq(nil) }
    end
  end
end

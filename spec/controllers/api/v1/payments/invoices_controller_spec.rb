require 'rails_helper'

RSpec.describe API::V1::Payments::InvoicesController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let!(:account) { create(:account, customer_id: 'cus_123') }
  let!(:user)    { create(:account_user, account: account, role: 'account_owner') }
  let!(:invoice) { create(:invoice, account: account) }

  subject(:get_invoices) { get(:index) }

  before { allow(Stripe::Customer).to receive(:retrieve) }

  describe 'GET /v1/payments/invoices' do
    context 'success' do
      let(:expected_json) do
        [{
          id: invoice.id,
          amount_due: invoice.amount_due,
          date: invoice.date.as_json,
          prorate_amount: invoice.lines.data.first.amount,
          receipt_number: nil,
          starting_balance: nil,
          subtotal: invoice.subtotal,
          tax: invoice.tax,
          tax_percent: invoice.tax_percent,
          total: invoice.total,
          file_id: invoice.generic_file&.id,
          line_items:  [{
            id: invoice.lines.data.first.id,
            amount: invoice.lines.data.first.amount,
            currency: invoice.lines.data.first.currency,
            period_start: invoice.lines.data.first.period_start.as_json,
            period_end: invoice.lines.data.first.period_end.as_json,
            proration: invoice.lines.data.first.proration,
            quantity: invoice.lines.data.first.quantity,
            subscription: invoice.lines.data.first.subscription,
            subscription_item: invoice.lines.data.first.subscription_item,
            type: invoice.lines.data.first.type,
            plan: {
              id: invoice.lines.data.first.plan.id,
              amount: invoice.lines.data.first.plan.amount,
              currency: invoice.lines.data.first.plan.currency,
              interval: invoice.lines.data.first.plan.interval,
              name: invoice.lines.data.first.plan.name,
              active: invoice.lines.data.first.plan.active,
              free: false
            }
          }]
        }]
      end

      before do
        account.available_modules.add(id: invoice.lines.data.first.plan.id)
        account.save!
        get_invoices
      end

      it { expect(response.status).to eq(200) }
      it { expect_json(expected_json) }
    end

    context 'errors' do
      context 'customer not created' do
        before do
          account.update!(customer_id: nil)
          get_invoices
        end

        it { expect(response.status).to eq(502) }
      end

      context 'user is not account_owner' do
        context 'user is account_administrator' do
          before do
            create(:account_user, account: user.account, role: 'account_owner')
            user.update!(role: 'account_administrator')
            get_invoices
          end

          it { expect(response.status).to eq(403) }
        end

        context 'user is regular user' do
          before do
            create(:account_user, account: user.account, role: 'account_owner')
            user.update!(role: 'user')
            get_invoices
          end

          it { expect(response.status).to eq(403) }
        end
      end
    end
  end
end

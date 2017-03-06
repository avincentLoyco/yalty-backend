require 'rails_helper'

RSpec.describe API::V1::Payments::SubscriptionsController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let(:account) { create(:account, :with_billing_information) }
  let(:user) { create(:account_user, role: 'account_administrator', account: account) }

  let!(:timestamp)   { Time.zone.now.to_i }
  let(:customer)     { StripeCustomer.new('cus_123', 'desc', 'ca_123') }
  let(:subscription) { StripeSubscription.new('sub_123', timestamp, 5) }
  let(:invoice)      { StripeInvoice.new('in_123', 666, timestamp) }
  let(:card)         { StripeCard.new('ca_123', 4567, 'Visa', 12, 2018) }
  let(:plans) do
    ['master-plan', 'evil-plan', 'sweet-sweet-plan'].map do |plan_id|
      StripePlan.new(plan_id, 400, 'chf', 'month', plan_id.titleize)
    end
  end
  let(:subscription_items) { [StripeSubscriptionItem.new('si_123', plans.first)] }

  before do
    Account.current.update(customer_id: customer.id, subscription_id: subscription.id)
    Account::User.current.update(role: 'account_owner')

    allow(Stripe::Customer).to receive(:retrieve).and_return(customer)
    allow(Stripe::Invoice).to receive(:upcoming).and_return(invoice)
    allow(Stripe::Subscription).to receive(:retrieve).and_return(subscription)
    allow(Stripe::Plan).to receive(:list).and_return(plans)
    allow(Stripe::SubscriptionItem).to receive(:list).and_return(subscription_items)
    allow_any_instance_of(StripeCustomer).to receive(:sources).and_return([card])
    allow_any_instance_of(StripeInvoice).to receive(:lines).and_return([])
  end

  describe '#GET /v1/payments/subscription' do
    let(:expected_json) do
      {
        id: subscription.id,
        current_period_end: '2016-01-01T00:00:00.000Z',
        quantity: subscription.quantity,
        plans: [
          {
            id: plans.first.id,
            amount: plans.first.amount,
            currency: plans.first.currency,
            interval: plans.first.interval,
            name: plans.first.name,
            active: true
          },
          {
            id: plans.second.id,
            amount: plans.second.amount,
            currency: plans.second.currency,
            interval: plans.second.interval,
            name: plans.second.name,
            active: false
          },
          {
            id: plans.third.id,
            amount: plans.third.amount,
            currency: plans.third.currency,
            interval: plans.third.interval,
            name: plans.third.name,
            active: false
          }
        ],
        invoice: {
          id: invoice.id,
          amount_due: invoice.amount_due,
          date: '2016-01-01T00:00:00.000Z',
          prorate_amount: 0,
          line_items: []
        },
        default_card: {
          id: card.id,
          last4: card.last4,
          brand: card.brand,
          exp_month: card.exp_month,
          exp_year: card.exp_year,
          default: card.default,
          name: card.name
        },
        billing_information: {
          company_information: {
            company_name: account.invoice_company_info.company_name,
            address_1: account.invoice_company_info.address_1,
            address_2: account.invoice_company_info.address_2,
            city: account.invoice_company_info.city,
            postalcode: account.invoice_company_info.postalcode,
            country: account.invoice_company_info.country,
            region: account.invoice_company_info.region
          },
          emails: account.invoice_emails
        }
      }
    end

    subject(:get_subscription) { get :index  }

    context 'when user is an account_owner' do
      before { get_subscription }

      it { expect(response.status).to eq(200) }
      it { expect_json(expected_json) }
    end

    context 'when user is not an account_owner but' do
      context 'an account_administrator' do
        before do
          Account::User.current.update!(role: 'account_administrator')
          get_subscription
        end

        it { expect(response.status).to eq(403) }
      end

      context 'a regular user' do
        before do
          Account::User.current.update(role: 'user')
          get_subscription
        end

        it { expect(response.status).to eq(403) }
      end
    end
  end

  describe '#PUT /v1/payments/subscription/settings' do
    let(:params) {{ company_information: invoice_company_info, emails: invoice_emails }}
    let(:invoice_emails) { ['bruce@wayne.com'] }
    let(:invoice_company_info) do
      attributes_for(:account, :with_billing_information)[:invoice_company_info]
    end

    subject(:update_settings) { put :settings, params }

    context 'update all settings' do\
      it { expect { update_settings }.to change { account.invoice_company_info } }
      it { expect { update_settings }.to change { account.invoice_emails } }

      context 'settings are valid' do
        before { update_settings }

        it 'invoice_company_info is valid' do
          invoice_company_info.keys.each do |key|
            expect(account.invoice_company_info[key]).to eq(invoice_company_info[key])
          end
        end
        it { expect(account.invoice_emails).to eq(invoice_emails) }
      end
    end

    context 'update only company_information' do
      let(:params) {{ company_information: invoice_company_info }}

      it { expect { update_settings }.to     change { account.invoice_company_info } }
      it { expect { update_settings }.to_not change { account.invoice_emails } }
    end

    context 'update only emails' do
      let(:params) {{ emails: invoice_emails }}

      it { expect { update_settings }.to_not change { account.invoice_company_info } }
      it { expect { update_settings }.to     change { account.invoice_emails } }
    end

    context 'empty params clear settings' do
      before do
        account.update(invoice_company_info: invoice_company_info, invoice_emails: invoice_emails)
      end

      let(:params) {{ company_information: nil, emails: nil }}

      it { expect { update_settings }.to change { account.invoice_company_info } }
      it { expect { update_settings }.to change { account.invoice_emails } }

      context 'settings are empty' do
        before { update_settings }

        it 'invoice_company_info is valid' do
          invoice_company_info.keys.each do |key|
            expect(account.invoice_company_info[key]).to eq(nil)
          end
        end
        it { expect(account.invoice_emails).to eq(nil) }
      end
    end

    context 'require params missing' do
      let(:params_error) { JSON.parse(response.body).fetch('errors').first }
      let(:params) {{ company_information: {} }}

      before { update_settings }

      it { expect(response.status).to eq(422) }
      it { expect(params_error['field']).to eq('company_information') }
      it 'returns missing params' do
        invoice_company_info.except(:address_2).keys.each do |key|
          expect(params_error['messages'][key.to_s]).to eq(['is missing'])
        end
      end
    end

    context 'account update fails' do
      before do
        allow(account).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(account))
        update_settings
      end

      it { expect(response.status).to eq(422) }
    end
  end
end

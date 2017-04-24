require "rails_helper"

RSpec.describe PaymentsMailer, type: :mailer do
  let(:card_id) { 'card_123' }
  let(:customer) do
    customer = Stripe::Customer.new(id: 'cus_123')
    customer.default_source = card_id
    customer.sources = customer_sources
    customer.subscriptions = customer_subscriptions
    customer
  end
  let(:customer_sources) do
    card = Stripe::Card.new(id: card_id)
    card.last4 = '4242'
    card.brand = 'Visa'
    card.exp_month = 10
    card.exp_year = 2018
    card.name = 'Name'
    [card]
  end
  let(:customer_subscriptions) do
    subscription = Stripe::Subscription.new(id: 'sub_123')
    subscription.current_period_end = 14.days.from_now.to_i
    [subscription]
  end
  let(:account) { create(:account, customer_id: 'cus_123', subscription_id: 'sub_123') }
  let!(:owner) { create(:account_user, account: account, role: 'account_owner') }

  before { allow(Stripe::Customer).to receive(:retrieve).and_return(customer) }

  context 'payment_succeeded' do
    let(:invoice_pdf) { create(:generic_file, :with_pdf) }
    let!(:invoice) do
      create(:invoice, account: account, status: 'success', generic_file: invoice_pdf)
    end

    subject(:mailer) { PaymentsMailer.payment_succeeded(invoice.id).deliver_now }

    it { expect { mailer }.to change { ActionMailer::Base.deliveries.count } }
    it { expect(mailer.attachments.size).to eq(1) }
    it { expect(mailer.to).to match_array([owner.email]) }
    it { expect(mailer.subject).to eq("#{account.company_name}: Your plan has been renewed") }

    context 'when invoice_emails set' do
      let(:recipients) { ['random@te.st'] }
      before { account.update!(invoice_emails: recipients) }

      it { expect(mailer.to).to match_array(recipients) }
    end
  end

  context 'payment_failed' do
    let(:invoice) { create(:invoice, account: account, status: 'failed') }

    subject(:mailer) { PaymentsMailer.payment_failed(invoice.id).deliver_now }

    it { expect { mailer }.to change { ActionMailer::Base.deliveries.count } }
    it { expect(mailer.attachments.size).to eq(0) }
    it { expect(mailer.subject).to eq('Payment failure! Check your yalty Account') }
  end

  context 'subscription_canceled' do
    subject(:mailer) { PaymentsMailer.subscription_canceled(account.id).deliver_now }

    it { expect { mailer }.to change { ActionMailer::Base.deliveries.count } }
    it { expect(mailer.attachments.size).to eq(0) }
    it { expect(mailer.subject).to eq('Payment failure - your premium features are deactivated') }
  end
end

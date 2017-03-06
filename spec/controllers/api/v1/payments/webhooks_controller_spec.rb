require 'rails_helper'

RSpec.describe API::V1::Payments::WebhooksController, type: :controller do
  include_context 'shared_context_headers'

  let(:event) { double('Stripe::Event', id: 'ev_123', type: 'invoice.created') }

  subject(:send_webhook) { post :webhook, { id: event.id }, @env }

  before do
    allow(Stripe::Event).to receive(:retrieve).and_return(event)
    basic_http_login('whatever', ENV['STRIPE_WEBHOOK_PASSWORD'])
  end

  context 'success' do
    it { is_expected.to have_http_status(200) }
    it 'runs the StripeEventsHandler job' do
      expect(::Payments::StripeEventsHandler).to receive(:perform_later).with(event.as_json)
      send_webhook
    end
  end

  context 'errors' do
    context 'Stripe error' do
      before { allow(Stripe::Event).to receive(:retrieve).and_raise(Stripe::APIError) }

      it { is_expected.to have_http_status(502) }
    end

    context 'basic auth fails' do
      before { basic_http_login('whatever', 'wrong password') }

      it { is_expected.to have_http_status(401) }
    end
  end
end

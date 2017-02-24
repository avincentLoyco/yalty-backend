require 'rails_helper'

RSpec.describe API::V1::Payments::CardsController, type: :controller do
  include_context 'shared_context_headers'

  let(:token_json) { { token: 'example_token' } }
  let(:customer_id) { 'cus_tomer' }

  context 'GET #index' do
    subject(:index_subject) { get :index }
    before { Account.current.update(customer_id: customer_id) }

    let(:card_id) { 'CardID' }

    let(:customer) do
      customer = Stripe::Customer.new
      customer.default_source = card_id
      customer.sources = cards_response
      customer
    end

    let(:cards_response) do
      card = Stripe::Card.new(id: card_id)
      card.last4 = '4242'
      card.brand = 'Visa'
      card.exp_month = 10
      card.exp_year = 2018
      card.name = 'Name'
      [card]
    end

    context 'when account owner' do
      before { Account::User.current.update(role: 'account_owner') }

      context 'has valid params' do
        before do
          allow(Stripe::Customer).to receive(:retrieve) { customer }
          index_subject
        end
        it { is_expected.to have_http_status(200) }
        it { expect_json_keys('0', [:id, :last4, :brand, :exp_month, :exp_year, :default, :name]) }
      end

      context 'when customer id does not exist' do
        let(:customer_id) { nil }
        before { index_subject }

        it { is_expected.to have_http_status(500) }
        it { expect_json(regex('customer_id is empty')) }
      end

      context 'when stripe service is unavailable' do
        before do
          allow(Stripe::Customer).to receive(:retrieve).and_raise(Stripe::APIError)
          index_subject
        end

        it { is_expected.to have_http_status(500) }
      end
    end

    context 'when account administrator' do
      before do
        Account::User.current.update(role: 'account_administrator')
        index_subject
      end

      it { is_expected.to have_http_status(403) }
    end
  end

  context 'POST #create' do
    subject(:post_subject) { post :create, token_json }
    before { Account.current.update(customer_id: customer_id) }

    context 'when account administrator' do
      before do
        Account::User.current.update(role: 'account_administrator')
        post_subject
      end

      it { is_expected.to have_http_status(403) }
    end

    context 'when account owner' do
      before { Account::User.current.update(role: 'account_owner') }

      context 'when stripe is available' do
        before do
          allow_any_instance_of(described_class)
            .to receive(:create_card).with(anything) { card_response }
          allow_any_instance_of(described_class).to receive(:customer) { customer }
        end
        let(:card_id) { 'CardID' }

        let(:customer) do
          customer = Stripe::Customer.new
          customer.default_source = card_id
          customer
        end

        let(:card_response) do
          card = Stripe::Card.new(id: card_id)
          card.last4 = '4242'
          card.brand = 'Visa'
          card.exp_month = 10
          card.exp_year = 2018
          card.name = 'Name'
          card
        end

        before { post_subject }

        it { is_expected.to have_http_status(200) }

        it do
          expect_json_types(
            id: :string,
            last4: :string,
            brand: :string,
            exp_month: :int,
            exp_year: :int,
            default: :bool,
            name: :string
          )
        end

        it do
          expect_json(
            id: card_response.id,
            last4: card_response.last4,
            brand: card_response.brand,
            exp_month: card_response.exp_month,
            exp_year: card_response.exp_year,
            default: card_response.default,
            name: card_response.name
          )
        end
      end

      context 'when stripe API is unviable' do
        before do
          allow(Stripe::Customer).to receive(:retrieve).and_raise(Stripe::APIError)
          post_subject
        end

        it { is_expected.to have_http_status(500) }
      end

      context 'when customer_id is not yet created' do
        let(:customer_id) { nil }
        before { post_subject }

        it { is_expected.to have_http_status(500) }
        it { expect_json(regex('customer_id is empty')) }
      end
    end
  end
end

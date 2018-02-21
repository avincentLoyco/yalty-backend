require "rails_helper"

RSpec.describe API::V1::Payments::CardsController, type: :controller do
  include_context "shared_context_headers"

  let(:token_json) { { token: "example_token" } }
  let(:customer_id) { "cus_tomer" }

  shared_examples "Stripe API errors" do
    context "when API error" do
      let(:stripe_error) { Stripe::APIError.new("message") }

      it { is_expected.to have_http_status(502) }
      it { expect(JSON.parse(response.body)["errors"].first["type"]).to eq("card") }
    end

    context "when invalid resource" do
      let(:stripe_error) { Stripe::InvalidRequestError.new("message", "something") }

      it { is_expected.to have_http_status(502) }
      it { expect(JSON.parse(response.body)["errors"].first["type"]).to eq("card") }
    end
  end

  shared_examples "Customer not created" do
    let(:customer_id) { nil }

    it { is_expected.to have_http_status(502) }
    it { expect_json(regex("Customer is not created")) }
  end

  context "GET #index" do
    subject(:index_subject) { get :index }
    before { Account.current.update(customer_id: customer_id) }

    let(:card_id) { "CardID" }

    let(:customer) do
      customer = Stripe::Customer.new
      customer.default_source = card_id
      customer.sources = cards_response
      customer
    end

    let(:cards_response) do
      card = Stripe::Card.new(id: card_id)
      card.last4 = "4242"
      card.brand = "Visa"
      card.exp_month = 10
      card.exp_year = 2018
      card.name = "Name"
      [card]
    end

    context "when account owner" do
      before { Account::User.current.update(role: "account_owner") }

      context "has valid params" do
        before do
          allow(Stripe::Customer).to receive(:retrieve) { customer }
          index_subject
        end

        it { is_expected.to have_http_status(200) }
        it { expect_json_keys("0", [:id, :last4, :brand, :exp_month, :exp_year, :default, :name]) }
      end

      context "when customer id does not exist" do
        before { index_subject }

        it_behaves_like "Customer not created"
      end

      context "when Stripe API fails" do
        before do
          allow(Stripe::Customer)
            .to receive_message_chain(:retrieve, :sources)
            .and_raise(stripe_error)
          index_subject
        end

        it_behaves_like "Stripe API errors"
      end
    end

    context "when user does not have rights" do
      before { index_subject }

      it { is_expected.to have_http_status(403) }
    end
  end

  context "POST #create" do
    subject(:post_subject) { post :create, token_json }
    before { Account.current.update(customer_id: customer_id) }

    context "when user does not have rights" do
      before { post_subject }

      it { is_expected.to have_http_status(403) }
    end

    context "when account owner" do
      before { Account::User.current.update(role: "account_owner") }

      context "when stripe is available" do
        before do
          allow_any_instance_of(described_class)
            .to receive(:create_card).with(anything) { card_response }
          allow_any_instance_of(described_class).to receive(:customer) { customer }
        end
        let(:card_id) { "CardID" }

        let(:customer) do
          customer = Stripe::Customer.new
          customer.default_source = card_id
          customer
        end

        let(:card_response) do
          card = Stripe::Card.new(id: card_id)
          card.last4 = "4242"
          card.brand = "Visa"
          card.exp_month = 10
          card.exp_year = 2018
          card.name = "Name"
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

      context "when Stripe API fails" do
        before do
          allow(Stripe::Customer)
            .to receive_message_chain(:retrieve, :sources, :create)
            .and_raise(stripe_error)
          post_subject
        end

        it_behaves_like "Stripe API errors"
      end

      context "when customer_id is not yet created" do
        before { post_subject }

        it_behaves_like "Customer not created"
      end
    end
  end

  context "PUT /v1/payments/cards/:card_id" do
    let(:customer) { StripeCustomer.new(customer_id, "desc", "test@email.com", "c_123") }
    let(:account)  { create(:account, customer_id: customer.id) }
    let(:user)     { create(:account_user, account: account, role: "account_owner") }
    let(:card_id)  { "new_id" }
    let(:params)   {{ id: card_id }}

    subject(:update_card) { put(:update, params) }

    before { allow(Stripe::Customer).to receive(:retrieve).and_return(customer) }

    it { expect { update_card }.to change { customer.default_source }.from("c_123").to("new_id") }
    it "saves customer" do
      expect(customer).to receive(:save).exactly(1).times
      update_card
    end

    context "response" do
      before { update_card }

      it { expect(response.status).to eq(204) }
    end

    context "custumer not created" do
      let(:customer_id) { nil }

      it { is_expected.to have_http_status(502) }
    end
  end

  context "DELETE #destroy" do
    subject(:destroy_subject) { delete :destroy, id_json }
    before { Account.current.update(customer_id: customer_id) }

    let(:id_json) { { id: card_id } }

    let(:card_id) { "CardID" }

    let(:customer) do
      customer = Stripe::Customer.new
      customer.default_source = card_id
      customer.sources = cards_response
      customer
    end

    let(:cards_response) do
      card = Stripe::Card.new(id: card_id)
      card.last4 = "4242"
      card.brand = "Visa"
      card.exp_month = 10
      card.exp_year = 2018
      card.name = "Name"
      [card]
    end

    context "when account owner" do
      before { Account::User.current.update(role: "account_owner") }
      let(:delete_response) do
        card = Stripe::Card.new(id: card_id)
        card.deleted = true
        card
      end

      context "with valid data" do
        before do
          allow(Stripe::Customer)
            .to receive_message_chain(:retrieve, :sources, :retrieve, :delete) { delete_response }
          destroy_subject
        end

        it { is_expected.to have_http_status(204) }
      end

      context "when customer is not created" do
        before { destroy_subject }

        it_behaves_like "Customer not created"
      end

      context "when Stripe API fails" do
        before do
          allow(Stripe::Customer)
            .to receive_message_chain(:retrieve, :sources, :retrieve, :delete)
            .and_raise(stripe_error)
          destroy_subject
        end

        it_behaves_like "Stripe API errors"
      end
    end

    context "when user does not have rights" do
      let(:customer_id) { "cus_tomer" }
      before { destroy_subject }

      it { is_expected.to have_http_status(403) }
    end
  end
end

require "rails_helper"

RSpec.describe AccountRemoval do
  let_it_be(:account) { create(:account) }
  let_it_be(:user) { create(:account_user, account: account) }

  let(:intercom_user) { instance_double(id: user.id, email: user.email) }
  let(:intercom_client) { double }
  let(:intercom_users) { double }

  let(:stripe_customer) { double }

  subject { described_class.new(account.subdomain).call }

  before do
    # Intercom stubs
    allow_any_instance_of(IntercomService)
      .to receive(:client).and_return(intercom_client)
    allow(intercom_client)
      .to receive(:users).and_return(intercom_users)
    allow(intercom_users)
      .to receive(:find).and_return(user)
    allow(intercom_users)
      .to receive(:delete)

    # Stripe stubs
    allow(account)
      .to receive(:stripe_enabled?).and_return(true)
    allow(Stripe::Customer)
      .to receive(:retrieve).and_return(stripe_customer)
    allow(stripe_customer)
      .to receive(:delete)
  end

  it "deletes stripe customer, intercom users connected to company and account" do
    expect { subject }.to change { Account.count }.by(-1)
  end

  context "when intercom user not found" do
    before do
      allow(intercom_users)
        .to receive(:find)
        .and_raise(Intercom::ResourceNotFound.new("message"))
    end

    it "handles the exception and adds message to logger" do
      expect(Rails.logger).to receive(:debug).with("message")
      expect { subject }.not_to raise_error
    end
  end

  context "when stripe customer not found" do
    before do
      allow(Stripe::Customer)
        .to receive(:retrieve)
        .and_raise(Stripe::InvalidRequestError.new("message", 0))
    end

    it "handles the exception and adds message to logger" do
      expect(Rails.logger).to receive(:debug).with("message")
      expect { subject }.not_to raise_error
    end
  end
end

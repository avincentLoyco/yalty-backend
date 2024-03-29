require "rails_helper"

RSpec.describe API::V1::Payments::SubscriptionsController, type: :controller do
  include_context "shared_context_headers"
  include_context "shared_context_timecop_helper"

  let(:account) do
    modules = [::Payments::PlanModule.new(id: "master-plan", canceled: false)]
    create(:account, :with_billing_information,
      available_modules: ::Payments::AvailableModules.new(data: modules))
  end
  let!(:employees) { create_list(:employee, 5, account: account) }
  let(:user) { create(:account_user, role: "account_administrator", account: account) }

  let!(:timestamp) { Time.zone.now.to_i }
  let(:customer) { StripeCustomer.new("cus_123", "desc", "test@email.com", "ca_123") }
  let(:subscription) do
    subscription = StripeSubscription.new("sub_123", timestamp)
    subscription.tax_percent = 8.0
    subscription
  end
  let(:invoice) { StripeInvoice.new("in_123", 666, timestamp) }
  let(:card) { StripeCard.new("ca_123", 4567, "Visa", 12, 2018) }
  let(:plans) do
    ["master-plan", "evil-plan", "sweet-sweet-plan", "free-plan"].map do |plan_id|
      StripePlan.new(plan_id, 400, "chf", "month", plan_id.titleize)
    end
  end
  let(:subscription_items) do
    [
      StripeSubscriptionItem.new("si_123", plans.first, 5),
      StripeSubscriptionItem.new("si_456", plans.last, 5),
    ]
  end

  before do
    Account.current.update(
      customer_id: customer.id,
      subscription_id: subscription.id,
      available_modules: Payments::AvailableModules.new(data: [
        Payments::PlanModule.new(id: plans.first.id, canceled: false),
        Payments::PlanModule.new(id: plans.second.id, canceled: true),
      ])
    )
    Account::User.current.update(role: "account_owner")

    allow(Stripe::Customer).to receive(:retrieve).and_return(customer)
    allow(Stripe::Invoice).to receive(:upcoming).and_return(invoice)
    allow(Stripe::Subscription).to receive(:retrieve).and_return(subscription)
    allow(Stripe::Plan).to receive(:list).and_return(plans)
    allow(Stripe::SubscriptionItem).to receive(:list).and_return(subscription_items)
    allow(subscription).to receive(:items).and_return(subscription_items)
    allow_any_instance_of(StripeCustomer).to receive(:sources).and_return([card])
    allow_any_instance_of(StripeInvoice).to receive_message_chain(:lines, :data).and_return([])
  end

  describe "#GET /v1/payments/subscription" do
    let(:expected_json) do
      {
        id: subscription.id,
        tax_percent: 8.0,
        current_period_end: "2016-01-01T00:00:00.000Z",
        quantity: 6,
        plans: [
          {
            id: plans.first.id,
            amount: plans.first.amount,
            currency: plans.first.currency,
            interval: plans.first.interval,
            name: plans.first.name,
            active: true,
            free: false,
          },
          {
            id: plans.second.id,
            amount: plans.second.amount,
            currency: plans.second.currency,
            interval: plans.second.interval,
            name: plans.second.name,
            active: false,
            free: false,
          },
          {
            id: plans.third.id,
            amount: plans.third.amount,
            currency: plans.third.currency,
            interval: plans.third.interval,
            name: plans.third.name,
            active: false,
            free: false,
          },
        ],
        invoice: {
          id: invoice.id,
          amount_due: invoice.amount_due,
          date: "2016-01-01T00:00:00.000Z",
          prorate_amount: 0,
          line_items: [],
        },
        default_card: {
          id: card.id,
          last4: card.last4,
          brand: card.brand,
          exp_month: card.exp_month,
          exp_year: card.exp_year,
          default: card.default,
          name: card.name,
        },
        billing_information: {
          company_information: {
            company_name: account.company_information.company_name,
            address_1: account.company_information.address_1,
            address_2: account.company_information.address_2,
            city: account.company_information.city,
            postalcode: account.company_information.postalcode,
            country: account.company_information.country,
            region: account.company_information.region,
            phone: account.company_information.phone,
          },
          emails: account.invoice_emails,
        },
      }
    end

    subject(:get_subscription) { get :index  }

    context "when user is an account_owner" do
      before { get_subscription }

      it { expect(response.status).to eq(200) }
      it { expect_json(expected_json) }
    end

    context "when user is not an account_owner but" do
      context "an account_administrator" do
        before do
          create(:account_user, account: Account::User.current.account, role: "account_owner")
          Account::User.current.update!(role: "account_administrator")
          get_subscription
        end

        it { expect(response.status).to eq(403) }
      end

      context "a regular user" do
        before do
          create(:account_user, account: Account::User.current.account, role: "account_owner")
          Account::User.current.update!(role: "user")
          get_subscription
        end

        it { expect(response.status).to eq(403) }
      end
    end

    context "free-plan is not returned" do
      let(:json_plans) { JSON.parse(response.body)["plans"] }
      before { get_subscription }

      it { expect(json_plans.size).to eq(3) }
      it { expect(json_plans.map { |plan| plan["id"] }).to_not include("free-plan") }
    end

    context "quantity shows active employee at next billing date" do
      let!(:employee_after_period_end) { create(:employee, account: account) }

      before do
        effective_at = Time.zone.at(timestamp) + 1.month
        employee_after_period_end.events.last.update!(effective_at: effective_at)
        get_subscription
      end

      it { expect_json(quantity: 6) }
    end

    context "do not include invoice if all modules are canceled at billing date" do
      before do
        account.available_modules.data.each do |mod|
          mod[:canceled] = true
        end
        account.save!
        get_subscription
      end

      it { expect_json(invoice: nil) }
    end

    context "do not include invoice if no module are active at billing date" do
      before do
        account.update!(available_modules: ::Payments::AvailableModules.new)
        get_subscription
      end

      it { expect_json(invoice: nil) }
    end
  end

  describe "#PUT /v1/payments/subscription/settings" do
    let(:params) {{ company_information: company_information, emails: invoice_emails }}
    let(:invoice_emails) { ["bruce@wayne.com"] }
    let(:company_information) do
      attributes_for(:account, :with_billing_information)[:company_information]
    end
    let(:invoice_empty_company_info) do
      info = attributes_for(:account, :with_billing_information)[:company_information]
      info.each { |k, _| info[k] = nil }
      info
    end

    subject(:update_settings) { put :settings, params }

    context "update all settings" do\
      it { expect { update_settings }.to change { account.company_information } }
      it { expect { update_settings }.to change { account.invoice_emails } }

      context "settings are valid" do
        before { update_settings }

        it "company_information is valid" do
          company_information.keys.each do |key|
            expect(account.company_information[key]).to eq(company_information[key])
          end
        end
        it { expect(account.invoice_emails).to eq(invoice_emails) }
      end
    end

    context "update only company_information" do
      let(:params) {{ company_information: company_information }}

      it { expect { update_settings }.to     change { account.company_information } }
      it { expect { update_settings }.to_not change { account.invoice_emails } }
    end

    context "update only emails" do
      let(:params) {{ emails: invoice_emails }}

      before { account.update!(invoice_emails: ["fake"]) }

      it { expect { update_settings }.to_not change { account.company_information } }
      it { expect { update_settings }.to     change { account.invoice_emails } }

      shared_examples "wrong parameter" do |error_message|
        before { update_settings }

        it { expect_json(regex(error_message)) }
      end

      context "emails is string" do
        let(:params) {{ emails: "string" }}

        it_behaves_like "wrong parameter", "must be an array"
      end

      context "emails is integer" do
        let(:params) {{ emails: 123 }}

        it_behaves_like "wrong parameter", "must be an array"
      end

      context "emails is nil" do
        let(:params) {{ emails: nil }}

        it { expect { update_settings }.to change { account.invoice_emails }.to([]) }
      end

      context "emails is empty array" do
        let(:params) {{ emails: [] }}

        it { expect { update_settings }.to change { account.invoice_emails }.to([]) }
      end
    end

    context "empty params clear settings" do
      before do
        account.update(company_information: company_information, invoice_emails: invoice_emails)
      end

      let(:params) {{ company_information: invoice_empty_company_info, emails: [] }}

      it { expect { update_settings }.to change { account.company_information } }
      it { expect { update_settings }.to change { account.invoice_emails } }

      context "settings are empty" do
        before { update_settings }

        it "company_information is valid" do
          expect(account.company_information).to be_a(Payments::CompanyInformation)

          company_information.keys.each do |key|
            expect(account.company_information[key]).to eq(nil)
          end
        end
        it { expect(account.invoice_emails).to be_an(Array) }
        it { expect(account.invoice_emails).to be_empty }
      end
    end

    context "require params missing" do
      let(:params_error) { JSON.parse(response.body).fetch("errors").first }
      let(:params) {{ company_information: { address_2: "test" } }}

      before { update_settings }

      it { expect(response.status).to eq(422) }
      it { expect(params_error["field"]).to eq("company_information") }
      it "returns missing params" do
        company_information.except(:address_2).each_key do |key|
          expect(params_error["messages"][key.to_s]).to eq(["is missing"])
        end
      end
    end

    context "account update fails" do
      before do
        allow(account).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(account))
        update_settings
      end

      it { expect(response.status).to eq(422) }
    end
  end
end

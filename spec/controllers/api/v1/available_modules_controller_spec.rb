require "rails_helper"

RSpec.describe API::V1::AvailableModulesController, type: :controller do
  include_context "shared_context_headers"

  let(:stripe_plans) do
    ["master-plan", "evil-plan", "sweet-sweet-plan", "free-plan"].map do |plan_id|
      StripePlan.new(plan_id, 400, "chf", "month", plan_id.titleize)
    end
  end

  let(:free_plans) do
    [{"id" => "automatedexport", "name" => "Automated Export"}]
  end

  before do
    allow(YAML).to receive(:load).and_return(free_plans)
    allow(Stripe::Plan).to receive(:list).and_return(stripe_plans)
  end

  context "#index GET /v1/available_modules" do
    subject(:get_index) { get(:index) }

    context "user with yalty role" do
      let(:expected_response) do
        [
          { id: "master-plan", name: "Master Plan", enabled: false, free: false },
          { id: "evil-plan", name: "Evil Plan", enabled: false, free: false },
          { id: "sweet-sweet-plan", name: "Sweet Sweet Plan", enabled: false, free: false },
          { id: "automatedexport", name: "Automated Export", enabled: true, free: true },
        ]
      end

      let(:user) do
        create(:account_user, account: account, role: "yalty", employee: nil,
          email: ENV["YALTY_ACCESS_EMAIL"]
        )
      end

      before do
        account.available_modules.add(id: "automatedexport", free: true)
        get_index
      end

      it { expect(response.status).to eq(200) }
      it { expect_json(expected_response) }
    end

    context "user with owner role" do
      let(:user) { create(:account_user, account: account, role: "account_owner") }

      before { get_index }

      it { expect(response.status).to eq(403) }
    end

    context "user with admin role" do
      let(:user) { create(:account_user, account: account, role: "account_administrator") }

      before { get_index }

      it { expect(response.status).to eq(403) }
    end

    context "user with user role" do
      let(:user) { create(:account_user, account: account, role: "user") }

      before { get_index }

      it { expect(response.status).to eq(403) }
    end
  end

  context "#update PUT /v1/available_modules/:id" do
    let(:free) { true }
    let(:plan_id) { "automatedexport" }
    let(:plan_module) { account.available_modules.find(plan_id) }

    subject(:put_update) { put(:update, { id: plan_id, free: free }) }

    context "user with yalty role" do
      let(:user) do
        create(:account_user, account: account, role: "yalty", employee: nil,
          email: "access@example.com")
      end

      context "plan is already active" do
        context "plan is free" do
          let(:free) { false }

          context "when plan is automatedexport" do
            before { account.available_modules.add(id: plan_id, free: true) }

            it { expect { put_update }.to change { account.available_modules.size }.by(-1) }
            it do
              expect { put_update }
                .to change { account.available_modules.include?(plan_id) }.from(true).to(false)
            end
          end

          context "when plan is not automatedexport" do
            let(:plan_id) { "master-plan" }
            before { account.available_modules.add(id: plan_id, free: true) }

            it { expect { put_update }.to_not change { account.available_modules.size } }
            it { expect { put_update }.to change { plan_module.free }.from(true).to(false) }
          end
        end

        context "plan is not free" do
          before { account.available_modules.add(id: plan_id, free: false) }

          it { expect { put_update }.to_not change { account.available_modules.size } }
          it { expect { put_update }.to change { plan_module.free }.from(false).to(true) }
        end
      end

      context "plan is not active yet" do
        let(:plan_id) { "automatedexport" }

        it { is_expected.to have_http_status(204) }
        it { expect { put_update }.to change { account.available_modules.size }.by(1) }

        context "response" do
          let(:expected_modules) do
            [Payments::PlanModule.new(id: plan_id, free: true, canceled: false)]
          end

          before { put_update }

          it { expect(account.available_modules.data.first.id).to eq("automatedexport") }
          it { expect(account.available_modules.data.first.canceled).to be(false) }
          it { expect(account.available_modules.data.first.free).to be(true) }
        end
      end
    end

    context "user with owner role" do
      let(:user) { create(:account_user, account: account, role: "account_owner") }

      before { put_update }

      it { expect(response.status).to eq(403) }
    end

    context "user with admin role" do
      let(:user) { create(:account_user, account: account, role: "account_administrator") }

      before { put_update }

      it { expect(response.status).to eq(403) }
    end

    context "user with user role" do
      let(:user) { create(:account_user, account: account, role: "user") }

      before { put_update }

      it { expect(response.status).to eq(403) }
    end
  end
end

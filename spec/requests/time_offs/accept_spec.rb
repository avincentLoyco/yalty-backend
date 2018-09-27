require "rails_helper"

RSpec.describe "Accept time-off request", type: :request do
  let_it_be(:account) { create(:account) }
  let_it_be(:category) { account.time_off_categories.first }
  let(:time_off) { create(:time_off, employee: employee, time_off_category: category) }

  let(:employee) { create(:employee, account: account, manager: manager) }

  let(:manager) { nil }

  let(:params) { {} }

  shared_examples "successfull approve" do
    let(:new_balance) do
      an_object_having_attributes(
        balance: time_off.balance,
        balance_type: "time_off",
        employee: employee,
        time_off_category: time_off.time_off_category
      )
    end

    it { is_expected.to have_http_status(:success) }

    it "changes time-off status to approved" do
      expect { approve_time_off }.to change { time_off.reload.approved? }.to(true)
    end

    it "creates balance" do
      expect { approve_time_off }.to change { time_off.reload.employee_balance }.from(nil).to(new_balance)
    end

    describe "notifications" do
      let(:employee_user) do
        build(:account_user)
      end

      let(:notification) do
        an_object_having_attributes(resource: time_off, notification_type: "time_off_approved")
      end

      before do
        employee.update!(user: employee_user)
        ActionMailer::Base.deliveries = []
      end

      it "sends an email" do
        approve_time_off

        expect(ActionMailer::Base.deliveries)
          .to contain_exactly(an_object_having_attributes(to: [employee_user.email]))
      end

      it "sends a notification" do
        approve_time_off

        expect(employee_user.notifications).to contain_exactly(notification)
      end
    end
  end

  describe "PUT /v1/time_offs/:time_off_id/approve", :auth_user do
    subject(:approve_time_off) do
      put(api_v1_time_off_approve_path(time_off.id), params, headers) && response
    end

    before do
      RequestStore.clear!
    end

    context "when accessing employee from other organization" do
      let_it_be(:auth_user) { create(:account_user, role: "account_owner") }

      it { is_expected.to have_http_status(:not_found) }
    end

    context "when logged in as account owner" do
      let_it_be(:auth_user) { create(:account_user, role: "account_owner", account: account) }

      it_behaves_like "successfull approve"

      context "when time off doesn't exist" do
        before do
          time_off.destroy!
        end

        it { is_expected.to have_http_status(:not_found) }
      end

      context "when time off already approved" do
        before do
          time_off.approve!
        end

        it { is_expected.to have_http_status(:success) }
      end

      context "when time off already declined" do
        before do
          time_off.decline!
        end

        it_behaves_like "successfull approve"
      end
    end

    context "when logged in as account admin" do
      let_it_be(:auth_user) do
        create(:account_user, role: "account_administrator", account: account)
      end

      it_behaves_like "successfull approve"
    end

    context "when logged in as normal user" do
      let_it_be(:auth_user) { create(:account_user, role: "user", account: account) }

      context "and is not manager for employee" do
        it { is_expected.to have_http_status(:forbidden) }
      end

      context "and is a manager for employee" do
        let(:manager) { auth_user }

        it_behaves_like "successfull approve"

        context "when time off already approved" do
          before do
            time_off.approve!
          end

          it { is_expected.to have_http_status(:forbidden) }
        end

        context "when time off already declined" do
          before do
            time_off.decline!
          end

          it { is_expected.to have_http_status(:forbidden) }
        end
      end
    end
  end
end

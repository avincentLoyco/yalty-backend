require "rails_helper"

RSpec.describe API::V1::TimeOffCategoriesController, type: :controller do
  include_examples "example_authorization",
    resource_name: "time_off_category"
  include_context "shared_context_headers"
  let(:expected_keys) { [:id, :type, :system, :name] }
  describe "GET #index" do
    let(:employee) { create(:employee, account: account) }
    let!(:time_off_categories) { create_list(:time_off_category, 3, account: account) }
    subject { get :index }
    let(:parsed_response) { JSON.parse(response.body) }

    it { is_expected.to have_http_status(200) }

    it "should return current account time off categories" do
      subject

      account.time_off_categories.each do |category|
        expect(response.body).to include category[:id]
      end
    end

    it "should not be visible in context of other account" do
      Account.current = create(:account)
      subject

      account.time_off_categories.each do |category|
        expect(parsed_response).to_not include category[:id]
      end
    end

    context "when employee id param is not given" do
      before { subject }

      it { expect_json_sizes(3) }
      it { expect(parsed_response.first.keys).to_not include "active_since" }
    end

    context "when employee id param is given" do
      subject { get :index, employee_id: employee.id }

      context "and employee does not have any time off categories" do
        before { subject }

        it { expect(parsed_response).to eq [] }
      end

      context "and employee has time off categories" do
        let!(:policies) do
          [1.month.ago, 3.weeks.ago].map do |effective_at|
            create(:employee_time_off_policy, :with_employee_balance,
              employee: employee, effective_at: effective_at)
          end
        end

        context "and employee was not rehired" do
          before { subject }

          it do
            expect(parsed_response.map { |res| res["periods"] }).to match_array(
              [
                [
                  {
                    "effective_since" => policies.first.effective_at.to_s,
                    "effective_till" => nil
                  }
                ],
                [
                  {
                    "effective_since" => policies.last.effective_at.to_s,
                    "effective_till" => nil
                  }
                ]
              ]
            )
          end
        end

        context "when employee wants to see other employee time off category" do
          before do
            user = create(:account_user, account: account, role: "user")
            Account::User.current = user
          end

          it { is_expected.to have_http_status(403) }
        end

        context "and employee was rehired" do
          before do
            user = create(:account_user, account: account, role: "user", employee: employee)
            Account::User.current = user
          end
          let!(:contract_end) do
            create(:employee_event,
              event_type: "contract_end", employee: employee, effective_at: Date.today)
          end
          let!(:rehired) do
            create(:employee_event,
              event_type: "hired", employee: employee, effective_at: 1.week.since)
          end
          let!(:new_etop) do
            create(:employee_time_off_policy,
              employee: employee, time_off_policy: policies.first.time_off_policy,
              effective_at: 1.week.since)
          end
          before { subject }

          it do
            expect(parsed_response.map { |res| res["periods"] }).to match_array(
              [
                [
                  {
                    "effective_since" => policies.first.effective_at.to_s,
                    "effective_till" => contract_end.effective_at.to_s
                  },
                  {
                    "effective_since" => new_etop.effective_at.to_s,
                    "effective_till" => nil
                  }
                ],
                [
                  {
                    "effective_since" => policies.last.effective_at.to_s,
                    "effective_till" => contract_end.effective_at.to_s
                  }
                ]
              ]
            )
          end
        end
      end
    end
  end

  describe "GET #show" do
    subject { get :show, id: id }
    let(:category) { create(:time_off_category, account: account) }

    context "with valid id" do
      let(:id) { category.id }

      it { is_expected.to have_http_status(200) }

      context "response body" do
        before { subject }

        it { expect_json_keys(expected_keys) }
        it { expect_json(
          id: category.id,
          type: "time_off_category",
          system: category.system,
          name: category.name
          )
        }
      end

      context " when the  user has an employee and the employee does " do
        let!(:employee) { user.employee }

        context " have a policy assigned to the category" do
          let(:policy) { create(:time_off_policy, time_off_category: category) }
          let!(:etop) do
            create(:employee_time_off_policy, time_off_policy: policy, employee: employee,
              effective_at: Time.zone.now
            )
          end

          before{ subject }

          it { expect_json(
            id: category.id,
            type: "time_off_category",
            system: category.system,
            name: category.name)
          }
        end

        context " not have a policy assigned to the category" do
          before{ subject }

          it { expect_json(
            id: category.id,
            type: "time_off_category",
            system: category.system,
            name: category.name)
          }
        end
      end
    end

    context "with invalid id" do
      context "time off with given id does not exist" do
        let(:id) { "abc" }

        it { is_expected.to have_http_status(404) }
      end

      context "time off category belongs to other account" do
        before { Account.current = create(:account) }
        let(:id) { category.id }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe "POST #create" do
    let(:name) { "testname" }
    let(:params) do
      {
        name: name,
        system: true
      }
    end
    subject { post :create, params }

    context "with valid params" do
      it { expect { subject }.to change { TimeOffCategory.where(system: false).count }.by(1) }
      it { expect { subject }.to_not change { TimeOffCategory.where(system: true).count } }

      it { is_expected.to have_http_status(201) }

      context "response body" do
        before { subject }

        it { expect_json_keys(expected_keys) }
      end
    end

    context "with invalid params" do
      context "with missing params" do
        before { params.delete(:name) }

        it { expect { subject }.to_not change { TimeOffCategory.count } }
        it { is_expected.to have_http_status(422) }
      end

      context "with params that do not pass validation" do
        let(:name) { "" }

        it { expect { subject }.to_not change { TimeOffCategory.count } }
        it { is_expected.to have_http_status(422) }
      end
    end
  end

  describe "PUT #update" do
    subject { put :update, params }
    let(:time_off_category) { create(:time_off_category, account: account) }
    let(:name) { "abc" }
    let(:id) { time_off_category.id }
    let(:params) do
      {
        id: id,
        name: name,
        system: "true"
      }
    end

    context "with valid data" do
      it { expect { subject }.to change { time_off_category.reload.name } }
      it { is_expected.to have_http_status(204) }

      context "it should not change system field even when set to true" do
        before { subject }

        it { expect(time_off_category.reload.system).to eq false }
      end
    end

    context "with invalid data" do
      context "with invalid id" do
        let(:id) { "abc" }

        it { expect { subject }.to_not change { time_off_category.reload.name  } }
        it { is_expected.to have_http_status(404) }
      end

      context "with missing params" do
        before { params.delete(:name) }

        it { expect { subject }.to_not change { time_off_category.reload.name  } }
        it { is_expected.to have_http_status(422) }
      end

      context "with params that do not pass validation" do
        let(:name) { "" }

        it { expect { subject }.to_not change { time_off_category.reload.name  } }
        it { is_expected.to have_http_status(422) }
      end

      context "with not editable resource" do
        let(:system_time_off_category) { create(:time_off_category, :system) }
        let(:id) { system_time_off_category.id }

        it { expect { subject }.to_not change { time_off_category.reload.name  } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe "DELETE #destroy" do
    before { allow_any_instance_of(TimeOff).to receive(:valid?) { true } }
    let!(:time_off_category) { create(:time_off_category, account: account) }
    let(:employee) { create(:employee, account: account) }
    let(:id) { time_off_category.id }
    subject { delete :destroy, id: id }

    context "with valid params" do
      it { expect { subject }.to change { TimeOffCategory.count }.by(-1) }
      it { is_expected.to have_http_status(204) }
    end

    context "with invalid params" do
      context "with invalid id" do
        let(:id) { "abc" }

        it { expect { subject }.to_not change { TimeOffCategory.count } }
        it { is_expected.to have_http_status(404) }
      end

      context "when time off category has time offs assigned" do
        let!(:time_off) do
          create(:time_off, time_off_category: time_off_category, employee: employee)
        end

        it { expect { subject }.to_not change { TimeOffCategory.count } }
        it { is_expected.to have_http_status(423) }
      end

      context "with not editable resource" do
        let(:system_time_off_category) { create(:time_off_category, :system) }
        let(:id) { system_time_off_category.id }

        it { expect { subject }.to_not change { time_off_category.reload.name  } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end

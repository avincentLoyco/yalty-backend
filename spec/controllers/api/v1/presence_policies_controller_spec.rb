# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::V1::PresencePoliciesController, type: :controller do
  include_context "shared_context_active_and_inactive_resources",
    resource_class: PresencePolicy.model_name,
    join_table_class: EmployeePresencePolicy.model_name
  include_examples "example_authorization",
    resource_name: "presence_policy"
  include_context "shared_context_headers"

  let(:first_employee)  { create(:employee, account: account) }
  let(:second_employee) { create(:employee, account: account) }
  let(:working_place)   { create(:working_place, account: account) }

  describe "GET #show" do
    let(:presence_policy) do
      create(:presence_policy, :with_presence_day,
        account: account, occupation_rate: 0.8
      )
    end
    subject { get :show, id: presence_policy.id }

    context "with valid data" do
      it { is_expected.to have_http_status(200) }

      context "response body" do
        before do
          create(:employee_presence_policy,
            presence_policy: presence_policy,
            employee: first_employee)
          subject
        end

        it { expect_json(id: presence_policy.id, name: presence_policy.name) }
        it { expect(response.body).to include(first_employee.id) }
        it do
          expect_json_keys([:id, :type, :name, :deletable, :occupation_rate, :presence_days, :assigned_employees])
        end
        it { expect_json("deletable", false) }
        it { expect_json("occupation_rate", 0.8) }
      end

      context "without employees" do
        before { subject }

        it { expect_json("deletable", true) }
      end
    end

    context "with invalid data" do
      context "with invalid id" do
        subject { get :show, id: "1" }

        it { is_expected.to have_http_status(404) }
      end

      context "when presence policy accessed from other account" do
        before(:each) do
          user = create(:account_user)
          Account.current = user.account
        end

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe "GET #index" do
    subject { get :index, { status: status } }

    let!(:inactive_presence_policies) do
      create_list(:presence_policy, 2, :with_presence_day, account: account,
        created_at: Date.new(2017, 2, 1),
        active: false)
    end

    let!(:active_presence_policies) do
      create_list(:presence_policy, 2, :with_presence_day, account: account,
        created_at: Date.new(2018, 1, 1),
        active: true)
    end

    before do
      active_presence_policy = active_presence_policies.last
      create(:employee_presence_policy, presence_policy: active_presence_policy, employee: first_employee)
      create(:employee_presence_policy, presence_policy: active_presence_policy, employee: second_employee)
    end

    context "with account presence policy" do
      let(:status) { "active" }
      before { subject }
      let(:presence_policy_with_employees) do
        JSON.parse(response.body).select { |p| p["assigned_employees"].present? }.first
      end
      let(:presence_policy_without_employees) do
        JSON.parse(response.body).select { |p| p["assigned_employees"].empty? && p["default_full_time"] == false }.first
      end

      it { expect_json_sizes(3) }
      it { is_expected.to have_http_status(200) }
      it do
        expect_json_keys("*", [:id, :type, :name, :deletable, :occupation_rate, :presence_days, :assigned_employees])
      end
      it { expect(response.body).to include(first_employee.id, second_employee.id) }

      it { expect(presence_policy_with_employees["deletable"]).to be false }
      it { expect(presence_policy_without_employees["deletable"]).to be true }
    end

    context "with not account presence policy" do
      let(:status) { "active" }
      before(:each) do
        user = create(:account_user)
        Account.current = user.account
      end

      context "response" do
        before { subject }

        it { expect_json_sizes(1) }
        it { expect(response.body).not_to eq [].to_json }
        it { expect(response).to have_http_status(200) }
      end
    end

    context "active/inactive policies" do
      let(:active_policy) { active_presence_policies.last }
      let(:inactive_policies) { inactive_presence_policies[0..1] }

      context "inactive policies" do
        let(:status) { "inactive" }

        before { subject }

        it { expect(response.body).to_not include active_policy.id }
        it { expect(response.body).to include(inactive_policies.first.id, inactive_policies.last.id) }
      end

      context "active policies" do
        let(:status) { "active" }

        before { subject }

        it { expect(response.body).to include active_policy.id }
        it { expect(response.body).to_not include(inactive_policies.first.id, inactive_policies.last.id) }
      end
    end
  end

  describe "POST #create" do
    let(:name)                  { "test" }
    let(:first_employee_id)     { first_employee.id }
    let(:second_employee_id)    { second_employee.id }
    let(:working_place_id)      { working_place.id }
    let(:days_params) do
      [
        {
          time_entries: [{ start_time: "12:00:00", end_time: "16:00:00" }],
          order: 1,
        },
        {
          time_entries: [{ start_time: "12:00:00", end_time: "16:00:00" }],
          order: 7,
        },
      ]
    end
    let(:valid_data_json) do
      {
        name: name,
        type: "presence_policy",
        occupation_rate: 0.8,
      }.merge(presence_days: days_params)
    end

    shared_examples "Invalid Id" do
      context "with invalid related record id" do
        it { expect { subject }.to_not change { PresencePolicy.count } }

        context "response" do
          before { subject }

          it { is_expected.to have_http_status(404) }
          it { expect_json(regex("Record Not Found")) }
        end
      end
    end

    context "with valid data" do
      subject { post :create, valid_data_json }

      it { expect { subject }.to change { PresencePolicy.count }.by(1) }

      context "response" do
        let(:json_keys) do
          [:id, :type, :name, :presence_days, :occupation_rate, :assigned_employees]
        end

        before { subject }

        it { is_expected.to have_http_status(201) }
        it { expect_json_keys(json_keys) }
      end

      context "presence days" do
        context "there is day with order 7" do
          it { expect { subject }.to change { PresencePolicy.count }.by(1) }
          it { expect { subject }.to change { PresenceDay.count }.by(2) }
          it { expect { subject }.to change { TimeEntry.count }.by(2) }

          it { is_expected.to have_http_status(201) }
        end

        context "there is no day with order 7" do
          before { days_params.pop }

          it { expect { subject }.to change { PresencePolicy.count }.by(1) }
          it { expect { subject }.to change { PresenceDay.count }.by(1) }
          it { expect { subject }.to change { TimeEntry.count }.by(1) }

          it { is_expected.to have_http_status(201) }
        end
      end
    end

    context "with invalid data" do
      context "without all required attributes" do
        let(:missing_data_json) { valid_data_json.tap { |json| json.delete(:name) } }
        subject { post :create, missing_data_json }

        it { expect { subject }.to_not change { PresencePolicy.count } }

        context "response" do
          before { subject }

          it { is_expected.to have_http_status(422) }
        end
      end

      context "without occupation rate" do
        let(:missing_or_data_json) { valid_data_json.tap { |json| json.delete(:occupation_rate) } }
        subject { post :create, missing_or_data_json }

        it { expect { subject }.to_not change { PresencePolicy.count } }

        context "response" do
          before { subject }

          it { is_expected.to have_http_status(422) }
        end
      end

      context "with data that do not pass validation" do
        shared_examples "params invalid" do |message|
          subject { post :create, valid_data_json }

          it { expect { subject }.to_not change { PresencePolicy.count } }

          context "response" do
            before { subject }

            it { is_expected.to have_http_status(422) }
            it { expect_json(regex(message)) }
          end
        end

        context "invalid name" do
          let(:name) { "" }

          it_behaves_like "params invalid", "must be filled"
        end
      end

      context "when days are not valid" do
        subject { post :create, valid_data_json }
        let(:days_params) do
          [
            {
              time_entries: [{ start_time: "12:00:00", end_time: "16:00:00" }],
              minutes: 40,
              order: 1,
            },
            {
              time_entries: [{ start_time: "12:00:00", end_time: "16:00:00" }],
              minutes: 40,
              order: 1,
            },
          ]
        end

        it { is_expected.to have_http_status(422) }
        it do
          subject

          expect(response.body).to include "has already been taken"
        end
      end
    end
  end

  describe "PUT #update" do
    let(:presence_policy) { create(:presence_policy, account: account) }

    let(:id) { presence_policy.id }
    let(:name) { "test" }
    let(:first_employee_id) { first_employee.id }
    let(:second_employee_id) { second_employee.id }
    let(:working_place_id) { working_place.id }
    let(:valid_data_json) do
      {
        id: id,
        name: name,
      }
    end

    shared_examples "Invalid Id" do
      context "with invalid related record id" do
        it { expect { subject }.to_not change { presence_policy.reload.name } }

        context "response" do
          before { subject }

          it { is_expected.to have_http_status(404) }
          it { expect_json(regex("Record Not Found")) }
        end
      end
    end

    context "with valid data" do
      subject { put :update, valid_data_json }

      # TODO use presence days for this test instead of standard_day_duration
      # context "when policy is not assigned to any employee" do
      #   it { expect { subject }.to change { presence_policy.reload.standard_day_duration } }
      #
      #   context "response" do
      #     before { subject }
      #
      #     it { is_expected.to have_http_status(204) }
      #   end
      # end

      context "when policy is assigned to some employee" do
        before do
          presence_policy.update!(presence_days: [create(:presence_day)])
          create(:employee_presence_policy,
            employee: first_employee,
            presence_policy: presence_policy
          )
        end

        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to change { presence_policy.reload.name } }
        it { expect { subject }.to_not change { presence_policy.reload.presence_days.count } }
      end

      context "when new occupation rate is passed" do
        before { valid_data_json[:occupation_rate] = 0.5 }

        it { expect { subject }.to change { presence_policy.reload.occupation_rate }.to(0.5) }
      end
    end

    context "with invalid data" do
      context "invalid records ids" do
        context "invalid presence policy id" do
          let(:id) { "1" }
          subject { put :update, valid_data_json }

          it_behaves_like "Invalid Id"
        end
      end

      context "missing data" do
        let(:missing_data_json) { valid_data_json.tap { |json| json.delete(:name) } }
        subject { put :update, missing_data_json }

        context "response" do
          before { subject }

          it { is_expected.to have_http_status(422) }
          it { expect_json(regex("missing")) }
        end
      end

      context "data do not pass validation" do
        let(:name) { "" }
        subject { put :update, valid_data_json }

        context "response" do
          before { subject }

          it { is_expected.to have_http_status(422) }
          it { expect_json(regex("must be filled")) }
        end
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:presence_policy) { create(:presence_policy, account: account) }
    let(:employee) { create(:employee, account: account) }
    let!(:presence_day) do
      create(:presence_day, presence_policy: presence_policy)
    end
    subject { delete :destroy, id: presence_policy.id }

    context "valid data" do
      it { is_expected.to have_http_status(204) }
      it { expect { subject }.to change { PresencePolicy.count }.by(-1) }
      it { expect { subject }.to change { PresenceDay.count}.by(-1) }

      context "and the policy is already assigned to an employee" do
        let!(:epp) do
          create(:employee_presence_policy, presence_policy: presence_policy, employee: employee)
        end
        it { is_expected.to have_http_status(423) }
        it { expect { subject }.to_not change { PresencePolicy.count } }
      end
    end

    context "invalid data" do
      context "invalid id" do
        subject { delete :destroy, id: "1" }

        it { expect { subject }.to_not change { PresencePolicy.count } }
        it { is_expected.to have_http_status(404) }
      end

      context "presence policy belongs to other account" do
        before(:each) do
          user = create(:account_user)
          Account.current = user.account
        end

        it { expect { subject }.to_not change { PresencePolicy.count } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end

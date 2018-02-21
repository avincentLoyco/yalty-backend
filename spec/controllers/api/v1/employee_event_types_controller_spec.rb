require "rails_helper"

RSpec.describe API::V1::EmployeeEventTypesController, type: :controller  do
  include_context "shared_context_headers"

  shared_examples "Invalid Authorization" do
    context "when user unauthorized" do
      context "when Account.current not set" do
        before { Account.current = nil }

        it { is_expected.to have_http_status(401) }

        context "response body" do
          before { subject }

          it { expect(response.body).to include("User unauthorized") }
        end
      end

      context "when Account::User.current not set" do
        before { Account::User.current = nil }

        it { is_expected.to have_http_status(401) }

        context "response body" do
          before { subject }

          it { expect(response.body).to include("User unauthorized") }
        end
      end
    end
  end

  describe "GET #show" do
    subject { get :show, employee_event_type: employee_event_type }
    let(:employee_event_type) { Employee::Event.event_types.last }

    context "with valid event type" do
      let(:event_attributes) { Employee::Event::EVENT_ATTRIBUTES[employee_event_type.to_sym] }

      it { is_expected.to have_http_status(200) }

      context "response body" do
        before { subject }

        it { expect_json(type: employee_event_type, attributes: event_attributes) }
      end
    end

    context "with invalid event type" do
      let(:employee_event_type) { "abc" }

      it { is_expected.to have_http_status(404) }

      context "response body" do
        before { subject }
        it { expect(response.body).to include("Event Type Not Found") }
      end
    end

    it_behaves_like "Invalid Authorization"
  end

  describe "GET #index" do
    subject { get :index }

    it { is_expected.to have_http_status(200) }

    context "response body" do
      before { subject }

      it { expect_json_sizes(Employee::Event.event_types.count) }
    end

    it_behaves_like "Invalid Authorization"
  end
end

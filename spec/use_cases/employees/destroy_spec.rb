# frozen_string_literal: true

require "rails_helper"

RSpec.describe Employees::Destroy do
  context "#call" do
    subject { described_class.new.call(employee) }

    let(:intercom_service) { double }
    let(:intercom_client) { double }
    let(:intercom_users) { double }
    let(:intercom_user) { double }

    before do
      # Intercom stubs
      allow(IntercomService)
        .to receive(:new).and_return(intercom_service)
      allow(intercom_service)
        .to receive(:client).and_return(intercom_client)
      allow(intercom_client)
        .to receive(:users).and_return(intercom_users)
      allow(intercom_users)
        .to receive(:find).with(user_id: employee.user&.id).and_return(intercom_user)
      allow(intercom_users)
        .to receive(:delete).with(intercom_user)
    end

    context "when employee has no user" do
      let_it_be(:employee) { create(:employee, user: nil) }

      it "destroys only an employee" do
        expect { subject }.to change(Employee, :count).by(-1)
        expect(intercom_users).not_to have_received(:delete)
      end
    end

    context "when employee has a user" do
      let_it_be(:employee) { create(:employee, role: "user") }

      it "destroys an employee and his intercom account" do
        expect { subject }.to change(Employee, :count).by(-1)
        expect(intercom_users).to have_received(:delete)
      end
    end
  end
end

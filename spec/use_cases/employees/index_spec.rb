# frozen_string_literal: true

require "rails_helper"

RSpec.describe Employees::Index do
  context "#call" do
    subject { described_class.new(account_model: account_model_mock).call(status: status) }

    let(:account_model_mock) { class_double(Account, current: account) }
    let(:account) { build(:account, employees: account_employees) }
    let(:account_employees) { build_list(:employee, 2) }

    before do
      allow(account_model_mock).to receive(:current).and_return(account)
    end

    context "when there is no status" do
      let(:status) { nil }

      before { allow(account.employees).to receive(:all).and_return(account_employees) }

      it "gets all account employees" do
        expect(subject).to eq(account_employees)
        expect(account.employees).to have_received(:all)
      end
    end

    context "when status is 'active'" do
      let(:status) { "active" }

      before { allow(account.employees).to receive(:active_at_date).and_return(account_employees) }

      it "gets active account employees" do
        expect(subject).to eq(account_employees)
        expect(account.employees).to have_received(:active_at_date)
      end
    end

    context "when status is 'inactive'" do
      let(:status) { "inactive" }

      before do
        allow(account.employees).to receive(:inactive_at_date).and_return(account_employees)
      end

      it "gets inactive account employees" do
        expect(subject).to eq(account_employees)
        expect(account.employees).to have_received(:inactive_at_date)
      end
    end
  end
end

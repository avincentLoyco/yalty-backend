# frozen_string_literal: true

require "rails_helper"

RSpec.describe Employees::Show do
  context "#call" do
    subject do
      described_class
        .new(get_account_employees: get_account_employees_mock)
        .call(employee.id)
    end

    let_it_be(:employee) { build(:employee) }
    let_it_be(:mocked_account_employees) { [employee] }
    let(:get_account_employees_mock) do
      instance_double(Employees::Index, call: mocked_account_employees)
    end

    before { allow(mocked_account_employees).to receive(:find).and_return(employee) }

    it "gets employees only for current account" do
      subject
      expect(get_account_employees_mock).to have_received(:call)
    end

    it "searches for requested employee in fetched account employees" do
      subject
      expect(mocked_account_employees).to have_received(:find).with(employee.id)
    end

    it "returns requested employee" do
      expect(subject).to eq(employee)
    end
  end
end

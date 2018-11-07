# frozen_string_literal: true

require "rails_helper"

RSpec.describe Balances::EndOfContract::Create do
  describe "#call" do
    subject do
      described_class
        .new(create_employee_balance_service: create_employee_balance_class_mock)
        .call(params)
    end

    let(:create_employee_balance_class) { CreateEmployeeBalance }

    let(:create_employee_balance_class_mock) do
      class_double(create_employee_balance_class, new: create_employee_balance_instance_mock)
    end

    let(:create_employee_balance_instance_mock) do
      instance_double(create_employee_balance_class, call: created_balance_mock)
    end

    let(:created_balance_mock) { "created_balance_mock" }

    let(:employee) { build(:employee) }
    let(:params) do
      {
        employee: employee,
        vacation_toc_id: SecureRandom.uuid,
        effective_at: Time.current,
        event_id: SecureRandom.uuid,
      }
    end

    it "calls create employee balance service with proper params" do
      subject
      expect(create_employee_balance_class_mock).to have_received(:new).with(
        params[:vacation_toc_id],
        employee.id,
        employee.account.id,
        balance_type: "end_of_contract",
        effective_at: params[:effective_at],
        skip_update: true,
        event_id: params[:event_id]
      )
      expect(create_employee_balance_instance_mock).to have_received(:call)
    end

    it { expect(subject).to eq(created_balance_mock) }
  end
end

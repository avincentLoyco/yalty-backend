# frozen_string_literal: true

require "rails_helper"

RSpec.describe Balances::EndOfContract::Create do
  describe "#call" do
    subject do
      described_class
        .new(
          create_employee_balance_service: create_employee_balance_class_mock,
          find_effective_at: find_effective_at_mock
        )
        .call(params)
    end

    let(:create_employee_balance_class) { CreateEmployeeBalance }

    let(:create_employee_balance_class_mock) do
      class_double(create_employee_balance_class, new: create_employee_balance_instance_mock)
    end

    let(:create_employee_balance_instance_mock) do
      instance_double(create_employee_balance_class, call: created_balance_mock)
    end

    let(:find_effective_at_mock) do
      instance_double(Balances::EndOfContract::FindEffectiveAt, call: mocked_effective_at)
    end

    let(:mocked_effective_at) { "mocked_effective_at" }
    let(:created_balance_mock) { "created_balance_mock" }
    let(:mocked_vacation_toc) { build(:time_off_category) }

    let(:employee) { build(:employee) }
    let(:params) do
      {
        employee: employee,
        contract_end_date: "contract_end_date",
        eoc_event_id: SecureRandom.uuid,
      }
    end

    before do
      allow(employee.account.time_off_categories).to receive(:find_by).and_return(
        mocked_vacation_toc
      )
    end

    it "finds vacation toc" do
      subject
      expect(employee.account.time_off_categories).to have_received(:find_by).with(name: "vacation")
    end

    it "finds effective_at" do
      subject
      expect(find_effective_at_mock).to have_received(:call).with(
        employee: employee,
        vacation_toc_id: mocked_vacation_toc.id,
        contract_end_date: params[:contract_end_date]
      )
    end

    it "calls create employee balance service with proper params" do
      subject
      expect(create_employee_balance_class_mock).to have_received(:new).with(
        mocked_vacation_toc.id,
        employee.id,
        employee.account.id,
        balance_type: "end_of_contract",
        effective_at: mocked_effective_at,
        skip_update: true,
        event_id: params[:eoc_event_id]
      )
      expect(create_employee_balance_instance_mock).to have_received(:call)
    end

    it { expect(subject).to eq(created_balance_mock) }
  end
end

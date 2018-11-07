# frozen_string_literal: true

require "rails_helper"

RSpec.describe Balances::EndOfContract::FindAndDestroy do
  describe "#call" do
    subject { described_class.new.call(params) }

    let(:employee) { create(:employee) }
    let(:eoc_date) { Time.current }
    let(:params) { { employee: employee, eoc_date: eoc_date } }

    context "when there is only one end of contract balance" do
      let!(:eoc_balance) do
        create(:employee_balance,
          employee: employee,
          effective_at: eoc_date - 10.days,
          balance_type: "end_of_contract")
      end

      it { expect { subject }.to change(employee.employee_balances, :count).by(-1) }
    end

    context "when there is more than one end of contract balance" do
      let!(:eoc_balance1) do
        create(:employee_balance,
          employee: employee,
          effective_at: eoc_date - 10.days,
          balance_type: "end_of_contract")
      end

      let!(:eoc_balance2) do
        create(:employee_balance,
          employee: employee,
          effective_at: eoc_date - 20.days,
          balance_type: "end_of_contract")
      end

      it { expect { subject }.to change(employee.employee_balances, :count).by(-1) }

      it "removes the first balance before eoc_date" do
        subject
        expect(employee.employee_balances).to match_array(eoc_balance2)
      end
    end

    context "when there is no end of contract balances" do
      it { expect { subject }.not_to change(employee.employee_balances, :count) }
    end
  end
end

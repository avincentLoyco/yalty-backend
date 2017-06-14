require 'rails_helper'

RSpec.describe DestroyEmployeeBalance, type: :service do
  let(:update) { true }
  let!(:employee) { create(:employee) }
  let!(:category) { create(:time_off_category, account: employee.account) }
  let!(:balances) do
    create_list(:employee_balance, 3, employee: employee, time_off_category: category)
  end

  subject { DestroyEmployeeBalance.new(balance, update).call }

  shared_examples 'Dependent balances update' do
    let(:balances_to_update) { balances - [balance].flatten }

    context 'when update flag is true' do
      it 'updates later balances' do
        subject

        balances_to_update.map do |balance|
          expect(balance.reload.being_processed).to eq true
        end
      end
    end

    context 'when update flag is false' do
      let(:update) { false }

      it 'does not update later balances' do
        subject

        balances_to_update.map do |balance|
          expect(balance.reload.being_processed).to eq false
        end
      end
    end
  end

  shared_examples 'Given balances and their removals destroy' do
    let(:to_destroy) do
      ids = balance.is_a?(Array) ? balance.map(&:id) : balance.id
      Employee::Balance.where(id: ids)
    end

    context 'when balances to destroy do not have removals' do
      it 'removes send balances' do
        subject

        to_destroy.map do |balance|
          expect(Employee::Balance.exists?(balance.id)).to eq false
        end
      end

      it { expect { subject }.to change { Employee::Balance.count }.by(-to_destroy.size) }
    end

    context 'when balances to destroy have removals' do
      before do
        TimeOffPolicy.not_reset.first.update!(end_day: 1, end_month: 4, years_to_effect: 1)
        to_destroy.map { |balance| UpdateEmployeeBalance.new(balance).call }
        [balance].flatten.map(&:reload)
      end

      let(:removals) { to_destroy.map(&:balance_credit_removal_id) }

      it 'removes proper balances' do
        subject

        to_destroy.map do |balance|
          expect(Employee::Balance.exists?(balance.id)).to eq false
        end
      end

      it 'removes balances removals' do
        subject

        removals.map do |removal_id|
          expect(Employee::Balance.exists?(removal_id)).to eq false
        end
      end

      it { expect { subject }.to change { Employee::Balance.count }.by(-2*(to_destroy.size)) }
    end
  end

  context 'when single balance send' do
    let(:balance) { balances.first }

    it_behaves_like 'Dependent balances update'
    it_behaves_like 'Given balances and their removals destroy'
  end

  context 'when array of balances send' do
    context 'when two balances send' do
      let!(:balance) { balances.first(2) }

      it_behaves_like 'Dependent balances update'
      it_behaves_like 'Given balances and their removals destroy'
    end

    context 'when all balances send' do
      let!(:balance) { balances.first(3) }

      it_behaves_like 'Dependent balances update'
      it_behaves_like 'Given balances and their removals destroy'
    end
  end
end

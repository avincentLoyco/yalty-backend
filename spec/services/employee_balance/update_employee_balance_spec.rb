require 'rails_helper'

RSpec.describe UpdateEmployeeBalance, type: :service do
  include_context 'shared_context_timecop_helper'

  before do
    allow_any_instance_of(Employee).to receive(:active_policy_in_category_at_date)
      .and_return(employee_policy)
    allow_any_instance_of(Employee).to receive(:active_policy_in_category_at_date)
      .and_return(employee_policy)
  end
  let(:account) { create(:account) }
  let(:category) { create(:time_off_category, account: account) }
  let(:employee) { create(:employee, account: account) }
  let(:policy) { create(:time_off_policy, time_off_category: category, effective_at: Time.now - 1.weeks) }
  let(:employee_policy) do
    create(:employee_time_off_policy, employee: employee)
  end
  let!(:previous_balance) do
    create(:employee_balance, :processing,
      effective_at: Time.now - 3.weeks, time_off_category: category, employee: employee, resource_amount: 0
    )
  end
  let(:employee_balance) { previous_balance.dup }
  subject { UpdateEmployeeBalance.new(employee_balance, options).call }
  before do
    employee_balance.effective_at = Time.now
    employee_balance.save
    previous_balance.save
  end

  context 'when amount not given' do
    let(:options) {{ resource_amount: nil }}

    context 'and employee balance is removal' do
      let!(:addition) do
        create(:employee_balance,
          validity_date: validity_date, effective_at: Time.now - 2.weeks, time_off_category: category,
          employee: previous_balance.employee, resource_amount: 600
        )
      end
      let!(:employee_balance) do
        create(:employee_balance, :processing,
          balance_credit_addition: addition, time_off_category: category,
          employee: previous_balance.employee, resource_amount: -100
        )
      end
      let(:validity_date) { Time.now - 1.weeks }

      subject { UpdateEmployeeBalance.new(employee_balance, options).call }

      it { expect { subject }.to change { employee_balance.reload.being_processed }.to false }
      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { expect { subject }.to change { employee_balance.reload.balance } }
      it { expect { subject }.to change { employee_balance.reload.amount } }

      context 'and update the last balance before removal' do
        let(:validity_date) { Time.now - 9.days }
        let(:amount) { 1000 }

        before do
          addition.update!(resource_amount: amount)
          subject
        end

        it { expect(employee_balance.amount).to eq -1000 }
        it { expect(employee_balance.effective_at).to eq validity_date }
        it { expect(employee_balance.balance).to eq 0 }
      end

      context 'and create the balance between addition and removal' do
        let!(:balance_in_the_middle) do
          create(:employee_balance,
            effective_at: Time.now - 9.days, time_off_category: category,
            employee: previous_balance.employee, resource_amount: amount
          )
        end

        context 'and balance amount is equals 100' do
          let(:amount) { 100 }
          before { subject }

          it { expect(employee_balance.amount).to eq -600 }
          it { expect(employee_balance.effective_at).to eq validity_date }
          it { expect(employee_balance.balance).to eq amount }
        end

        context 'and balance amount is equals -100' do
          let(:amount) { -100 }
          before { subject }

          it { expect(employee_balance.amount).to eq -500 }
          it { expect(employee_balance.effective_at).to eq validity_date }
          it { expect(employee_balance.balance).to eq 0 }
        end

        context 'and balance amount is equals -600' do
          let(:amount) { -addition.amount }
          before { subject }

          it { expect(employee_balance.amount).to eq 0 }
          it { expect(employee_balance.effective_at).to eq validity_date }
          it { expect(employee_balance.balance).to eq 0 }
        end

        context 'and balance amount is equals -1000' do
          let(:amount) { -1000 }
          before { subject }

          it { expect(employee_balance.amount).to eq 0 }
          it { expect(employee_balance.effective_at).to eq validity_date }
          it { expect(employee_balance.balance).to eq -400 }
        end
      end
    end

    context 'and employee balance is not removal' do
      it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end

    context 'and employee balances is a reset_balance' do
      let(:options) { {} }
      before do
        employee_balance.reset_balance = true
        employee_balance.save
      end
      it { expect { subject }.to change { employee_balance.reload.being_processed }.to false }
      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { expect { subject }.to_not change { employee_balance.reload.balance } }
      it { expect { subject }.to_not change { employee_balance.reload.amount } }
    end
  end

  context 'when amount given' do
    let(:options) {{ resource_amount: 100 }}

    it { expect { subject }.to change { employee_balance.reload.being_processed }.to false }
    it { expect { subject }.to_not change { Employee::Balance.count } }
    it { expect { subject }.to change { employee_balance.reload.balance } }
    it { expect { subject }.to change { employee_balance.reload.amount } }
  end

  context 'when validity date given' do
    context 'and employee balance already have removal' do
      before do
        employee_balance.update!(effective_at: Time.now - 1.month, validity_date: Time.now - 2.days)
      end
      let!(:removal) do
        create(:employee_balance,
          employee: employee_balance.employee,
          time_off_category: employee_balance.time_off_category,
          balance_credit_addition: employee_balance,
          policy_credit_removal: true
        )
      end

      context 'and employee balance have validity date in future' do
        let!(:options) {{ validity_date: Time.now + 2.days }}

        it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
        it { expect { subject }.to change { Employee::Balance.exists?(id: removal.id) } }
      end

      context 'and employee balance have validity date in past' do
        let!(:options) {{ validity_date: Time.now - 1.days }}

        it { expect { subject }.to_not change { Employee::Balance.count } }
        it { expect { subject }.to_not change { Employee::Balance.exists?(id: removal.id) } }
        it { expect { subject }.to change { removal.reload.effective_at } }
      end
    end

    context 'and employee balance does not have removal' do
      before do
        employee_balance.update!(effective_at: Time.now - 1.month)
      end

      context 'and new validity date in past' do
        let!(:options) {{ validity_date: Time.now - 2.days }}

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to change { employee_balance.reload.balance_credit_removal } }
      end

      context 'and new validity date in future' do
        let!(:options) {{ validity_date: Time.now + 2.days }}

        it { expect { subject }.to_not change { Employee::Balance.count } }
      end
    end
  end
end

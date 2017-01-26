require 'rails_helper'

RSpec.describe UpdateEmployeeBalance, type: :service do
  include_context 'shared_context_timecop_helper'

  let(:account) { create(:account) }
  let(:category) { create(:time_off_category, account: account) }
  let(:employee) { create(:employee, account: account) }
  let(:policy) { create(:time_off_policy, :with_end_date, time_off_category: category) }
  let!(:employee_policy) do
    create(:employee_time_off_policy,
      employee: employee, time_off_policy: policy, effective_at: 2.years.ago - 1.day)
  end
  let!(:previous_balance) do
    create(:employee_balance_manual, :processing,
      effective_at: employee_policy.effective_at, time_off_category: category, employee: employee,
      resource_amount: 0)
  end
  let(:employee_balance) { previous_balance.dup.tap { |balance| balance.update!(effective_at: Time.now) } }

  subject { UpdateEmployeeBalance.new(employee_balance, options).call }

  context 'when amount not given' do
    let(:options) {{ resource_amount: nil }}

    context 'and employee balance is removal' do
      let!(:addition) do
        create(:employee_balance_manual,
          validity_date: validity_date, effective_at: 2.years.ago, time_off_category: category,
          employee: previous_balance.employee, resource_amount: 600
        )
      end
      let!(:employee_balance) do
        create(:employee_balance_manual, :processing,
          balance_credit_additions: [addition], time_off_category: category,
          employee: previous_balance.employee, resource_amount: -100, effective_at: 9.months.ago
        )
      end
      let(:validity_date) { 9.months.ago }

      subject { UpdateEmployeeBalance.new(employee_balance, options).call }

      it { expect { subject }.to change { employee_balance.reload.being_processed }.to false }
      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { expect { subject }.to change { employee_balance.reload.balance } }
      it { expect { subject }.to change { employee_balance.reload.amount } }

      context 'and update the last balance before removal' do
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
        let(:time_off) do
          create(:time_off,
            employee: employee, time_off_category: category, start_time: 1.year.ago,
            end_time: 1.year.ago)
        end
        let!(:balance_in_the_middle) do
          time_off.employee_balance.tap do |balance|
            balance.update!(
              manual_amount: amount, validity_date: employee_balance.effective_at + 1.year
            )
          end
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
    before { employee_balance }
    let(:options) {{ resource_amount: 100 }}

    it { expect { subject }.to change { employee_balance.reload.being_processed }.to false }
    it { expect { subject }.to_not change { Employee::Balance.count } }
    it { expect { subject }.to change { employee_balance.reload.balance } }
    it { expect { subject }.to change { employee_balance.reload.amount } }
  end

  context 'when validity date given' do
    context 'and employee balance already have removal' do
      before do
        employee_balance.update!(effective_at: 2.years.ago, validity_date: 1.year.ago - 9.months)
      end
      let!(:removal) do
        create(:employee_balance,
          employee: employee_balance.employee,
          time_off_category: employee_balance.time_off_category,
          balance_credit_additions: [employee_balance],
          effective_at: 9.months.ago
        )
      end

      context 'and employee balance have validity date in future' do
        let!(:options) {{ validity_date: nil }}

        it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
        it { expect { subject }.to change { Employee::Balance.exists?(id: removal.id) } }
      end
    end

    context 'and employee balance does not have removal' do
      before { employee_balance.update!(effective_at: 1.year.ago) }

      context 'and new validity date in past' do
        let!(:options) {{ validity_date: 9.months.ago }}

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to change { employee_balance.reload.balance_credit_removal } }
      end

      context 'and new validity date in future' do
        let!(:options) {{ validity_date: 4.months.since }}

        it { expect { subject }.to_not change { Employee::Balance.count } }
      end
    end
  end
end

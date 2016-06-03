require 'rails_helper'

RSpec.describe CreateEmployeeBalance, type: :service do
  include_context 'shared_context_account_helper'
  include ActiveJob::TestHelper

  before do
    Account.current = create(:account)
    allow_any_instance_of(Employee).to receive(:active_policy_in_category_at_date)
      .and_return(employee_policy)
  end

  let(:category) { create(:time_off_category, account: Account.current) }
  let(:policy) { create(:time_off_policy, time_off_category: category) }
  let(:employee) { create(:employee, account: Account.current) }
  let(:employee_policy) do
    build(:employee_time_off_policy, time_off_policy: policy, effective_at: Date.today - 5.years)
  end
  let(:amount) { -100 }

  shared_examples 'employee balance with other employee balances after' do
    let!(:employee_balance) do
      create(:employee_balance, employee: employee, time_off_category: category,
        effective_at: Time.now + 10.days)
    end

    it { expect { subject }.to change { employee_balance.reload.being_processed }.from(false).to(true) }
    it { expect { subject }.to change { enqueued_jobs.size } }

    context 'and skip_update options is given' do
      let(:options) {{ skip_update: true }}

      it { expect { subject }.not_to change { employee_balance.reload.being_processed } }
      it { expect { subject }.not_to change { enqueued_jobs.size } }
    end
  end

  shared_examples 'employee balance without any employee balances after' do
    it { expect(subject.first.being_processed).to eq false }
    it { expect { subject }.not_to change { enqueued_jobs.size } }
  end

  context 'with valid data' do
    subject { CreateEmployeeBalance.new(category.id, employee.id, Account.current.id, amount).call }

    context 'only base params given' do
      it { expect { subject }.to change { Employee::Balance.count }.by(1) }
      it { expect { subject }.to_not change { enqueued_jobs.size } }

      it { expect(subject.first.amount).to eq -100 }
      it { expect(subject.first.validity_date).to eq nil }
      it { expect(subject.first.effective_at).to be_kind_of(Time) }
      it { expect(subject.first.balance_credit_removal).to eq nil }
    end

    context 'extra params given' do
      subject do
        CreateEmployeeBalance.new(
          category.id, employee.id, Account.current.id, amount, options
        ).call
      end
      let(:amount) { 100 }

      context 'and employee balance effective at is in the future' do
        let(:options) {{ effective_at: Time.now + 9.days }}

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to_not change { enqueued_jobs.size } }

        it { expect(subject.first.amount).to eq 100 }
        it { expect(subject.first.validity_date).to eq nil }
        it { expect(subject.first.effective_at).to be_kind_of(Time) }
        it { expect(subject.first.balance_credit_removal).to eq nil }

        it_behaves_like 'employee balance without any employee balances after'
        it_behaves_like 'employee balance with other employee balances after'
      end

      context 'and employee balances effective_at is in the past or today' do
        context 'and is today' do
          let(:options) {{ effective_at: Time.now }}

          it { expect { subject }.to change { Employee::Balance.count }.by(1) }

          it { expect(subject.first.amount).to eq 100 }
          it { expect(subject.first.validity_date).to eq nil }
          it { expect(subject.first.effective_at).to be_kind_of(Time) }
          it { expect(subject.first.balance_credit_removal).to eq nil }
        end

        context 'and is in the past' do
          context 'with no validity_date' do
            let(:options) {{ effective_at: Time.now - 1.year }}

            it { expect { subject }.to change { Employee::Balance.count }.by(1) }

            it { expect(subject.first.amount).to eq 100 }
            it { expect(subject.first.validity_date).to eq nil }
            it { expect(subject.first.effective_at).to be_kind_of(Time) }
            it { expect(subject.first.balance_credit_removal).to eq nil }

            it_behaves_like 'employee balance without any employee balances after'
            it_behaves_like 'employee balance with other employee balances after'
          end

          context 'with validity_date in the past' do
            let(:options) {{ effective_at: Time.now - 1.year, validity_date: Time.now - 1.month }}

            it { expect { subject }.to change { Employee::Balance.count }.by(2) }
            it { expect(subject.first.amount).to eq 100 }
            it { expect(subject.first.validity_date).to be_kind_of(Time) }
            it { expect(subject.first.effective_at).to be_kind_of(Time) }
            it { expect(subject.size).to eq 2 }
            it { expect(subject.first.balance_credit_removal).to be_kind_of(Employee::Balance) }
            it { expect(subject.last.balance_credit_addition).to eq subject.first }

            it_behaves_like 'employee balance without any employee balances after'
            it_behaves_like 'employee balance with other employee balances after'
          end

          context 'and employee balance is between addition and removal' do
            let(:options) {{ effective_at: Time.now - 1.year, validity_date: Time.now - 1.month }}
            let!(:employee_balance) do
              create(:employee_balance, employee: employee, time_off_category: category,
                effective_at: Time.now - 2.month, amount: -amount)
            end
            it { expect { subject }.to change { employee_balance.reload.being_processed } }
            it { expect { subject }.to change { enqueued_jobs.size } }
            it { expect(subject.last.amount).to eq 0 }
          end
        end
      end

      context 'effective date is after an existing balance effective date from another policy' do
        let(:amount) { 100 }
        let(:options) do
          { effective_at: Time.now - 1.month, validity_date: Time.now + 1.month }
        end
        let!(:other_working_place_policy) do
          create(:employee_time_off_policy, time_off_policy: other_policy,
            effective_at: Time.zone.now - 1.month
          )
        end

        context 'in the same category' do
          let(:other_policy) { create(:time_off_policy, time_off_category: category) }
          let!(:employee_balance) do
            create(:employee_balance,
              employee: employee, effective_at: Time.now - 2.month, time_off_category: category,
              amount: 100
            )
          end

          it { expect { subject }.not_to change { enqueued_jobs.size } }
          it { expect(subject.first.balance).to eq 200 }
        end

        context 'in a different category' do
          let(:new_category) { create(:time_off_category, account: Account.current) }
          let(:other_policy) { create(:time_off_policy, time_off_category: new_category) }
          let!(:new_policy) do
            create(:employee_time_off_policy,
              employee: employee,
              time_off_policy: other_policy,
              effective_at: Date.today - 1.years
            )
          end
          let!(:employee_balance) do
            create(:employee_balance,
              employee: employee, effective_at: Time.now - 2.month,
              time_off_category: new_category,
              amount: 100
            )
          end

          it { expect { subject }.not_to change { enqueued_jobs.size } }
          it { expect(subject.first.balance).to eq 100 }
        end
      end

      context 'time off given' do
        let(:options) {{ time_off_id: time_off.id }}
        let(:time_off) do
          create(:time_off, :without_balance, employee: employee, time_off_category: category)
        end

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to_not change { enqueued_jobs.size } }

        it { expect(subject.first.amount).to eq 100 }
        it { expect(subject.first.validity_date).to be nil }
        it { expect(subject.first.effective_at).to be_kind_of(Time) }
        it { expect(subject.first.policy_credit_removal).to be false }
        it { expect(subject.first.time_off).to be_kind_of(TimeOff) }
        it { expect(subject.first.time_off.id).to eq time_off.id }
      end

      context 'balance credit addition given' do
        let!(:employee_balance) do
          create(:employee_balance,
            time_off_category: category, employee: employee, amount: 1000
          )
        end

        let(:options) {{ balance_credit_addition_id: employee_balance.id }}

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to_not change { enqueued_jobs.size } }

        it { expect(subject.first.amount).to eq -1000 }
        it { expect(subject.first.validity_date).to be nil }
        it { expect(subject.first.effective_at).to be_kind_of(Time) }
        it { expect(subject.first.policy_credit_removal).to be true }
        it { expect(subject.first.balance_credit_addition_id).to eq(employee_balance.id) }
      end
    end

    context 'when the balance is a reset balance' do
      let(:amount) { 0 }
      let(:options) { { reset_balance: true } }

      it { expect(subject.first.amount).to eq 0 }
      it { expect(subject.first.balance).to eq 0 }
      it { expect(subject.first.validity_date).to eq nil }
      it { expect(subject.first.effective_at).to be_kind_of(Time) }
      it { expect(subject.first.balance_credit_removal).to eq nil }
      it { expect(subject.first.balance_credit_addition_id).to eq nil }
    end
  end

  context 'with invalid data' do
    subject { CreateEmployeeBalance.new(category.id, employee.id, Account.current.id, amount).call }

    context 'missing param' do
      context 'missing category' do
        subject { CreateEmployeeBalance.new(nil, employee.id, Account.current.id, amount).call }

        it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
      end

      context 'missing employee' do
        subject { CreateEmployeeBalance.new(category.id, nil, Account.current.id, amount).call }

        it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
      end

      context 'missing account' do
        subject { CreateEmployeeBalance.new(category.id, employee.id, nil, amount).call }

        it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
      end

      context 'missing amount' do
        subject do
          CreateEmployeeBalance.new(category.id, employee.id, Account.current.id, nil).call
        end

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end
    end
  end
end

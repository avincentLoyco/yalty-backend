require 'rails_helper'

RSpec.describe CreateEmployeeBalance, type: :service do
  include_context 'shared_context_account_helper'
  include ActiveJob::TestHelper
  before do
    Account.current = create(:account)
    allow_any_instance_of(Employee).to receive(:active_policy_in_category_at_date)
      .and_return(working_place_policy)
    allow_any_instance_of(Employee).to receive(:active_related_time_off_policy)
      .and_return(working_place_policy)
  end

  let(:category) { create(:time_off_category, account: Account.current) }
  let(:policy) { create(:time_off_policy, time_off_category: category) }
  let(:employee) do
    create(:employee, account: Account.current, working_place: working_place_policy.working_place)
  end
  let(:working_place_policy) do
    build(:working_place_time_off_policy,
      time_off_policy: policy, effective_at: Date.today - 5.years
    )
  end
  let(:amount) { -100 }

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
      context 'validity date given' do
        let(:amount) { 100 }

        context 'and in future' do
          let(:options) {{ validity_date: (Time.now + 1.month).to_s }}

          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          it { expect { subject }.to_not change { enqueued_jobs.size } }

          it { expect(subject.first.amount).to eq 100 }
          it { expect(subject.first.validity_date).to be_kind_of(Time) }
          it { expect(subject.first.effective_at).to be_kind_of(Time) }
          it { expect(subject.first.balance_credit_removal).to eq nil }
        end

        context 'and in past' do
          let(:options) do
            { effective_at: Time.now - 1.year, validity_date: (Time.now - 1.month).to_s }
          end

          it { expect { subject }.to change { Employee::Balance.count }.by(2) }

          it { expect(subject.first.amount).to eq 100 }
          it { expect(subject.first.validity_date).to be_kind_of(Time) }
          it { expect(subject.first.effective_at).to be_kind_of(Time) }
          it { expect(subject.first.balance_credit_removal).to be_kind_of(Employee::Balance) }

          context 'no other balances' do
            it { expect { subject }.to_not change { enqueued_jobs.size } }
          end

          context 'balance after policy' do
            let!(:employee_balance) do
              create(:employee_balance,
                employee: employee, effective_at: Time.now - 2.months, time_off_category: category
              )
            end

            it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
          end

          context 'balance in current balance period' do
            let!(:employee_balance) do
              create(:employee_balance,
                employee: employee, effective_at: Time.now, time_off_category: category
              )
            end

            it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
          end
        end
      end

      context 'effective date is after an existing balance effective date from another policy' do
        let(:amount) { 100 }
        let(:options) do
          { effective_at: Time.now - 1.month, validity_date: (Time.now + 1.month).to_s }
        end
        let!(:other_working_place_policy) do
          create(:working_place_time_off_policy, time_off_policy: other_policy,
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
        context 'in a different category category' do
          let(:new_category) { create(:time_off_category, account: Account.current) }
          let(:other_policy) { create(:time_off_policy, time_off_category: new_category) }
          let!(:new_policy) do
            create(:working_place_time_off_policy,
              working_place: employee.working_place,
              time_off_policy: other_policy,
              effective_at: Date.today - 1.years
            )
          end
          let!(:employee_balance) do
            create(:employee_balance,
              employee: employee, effective_at: Time.now - 2.month,
              time_off_category: category,
              amount: 100
            )
          end

          it { expect { subject }.not_to change { enqueued_jobs.size } }
          it { expect(subject.first.balance).to eq 200 }
        end
      end

      context 'time off given' do
        let(:options) {{ time_off_id: time_off.id }}
        let(:time_off) do
          create(:time_off, :without_balance, employee: employee, time_off_category: category)
        end

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to_not change { enqueued_jobs.size } }

        it { expect(subject.first.amount).to eq -100 }
        it { expect(subject.first.validity_date).to be nil }
        it { expect(subject.first.effective_at).to be_kind_of(Time) }
        it { expect(subject.first.policy_credit_removal).to be false }
        it { expect(subject.first.time_off).to be_kind_of(TimeOff) }
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

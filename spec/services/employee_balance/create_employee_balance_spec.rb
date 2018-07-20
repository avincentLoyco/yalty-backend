require "rails_helper"

RSpec.describe CreateEmployeeBalance, type: :service, jobs: true do
  include_context "shared_context_account_helper"
  include_context "shared_context_timecop_helper"

  before { Account.current = create(:account) }

  let(:category) { create(:time_off_category, account: Account.current) }
  let(:policy) { create(:time_off_policy, :with_end_date, time_off_category: category) }
  let(:employee) { create(:employee, account: Account.current) }
  let!(:employee_policy) do
    create(:employee_time_off_policy,
      time_off_policy: policy, employee: employee, effective_at: Date.today - 5.years)
  end

  subject do
    described_class.new(
      category.id,
      employee.id,
      Account.current.id,
      { resource_amount: amount, manual_amount: 0 }.merge(options).merge(type)
    ).call
  end
  let(:amount) { -100 }

  shared_examples "employee balance with other employee balances after" do
    let!(:employee_balance) do
      create(:employee_balance_manual, employee: employee, time_off_category: category,
        effective_at: 2.years.since)
    end

    it { expect { subject }.to change { employee_balance.reload.being_processed }.from(false).to(true) }

    context "and skip_update options is given" do
      let(:options) {{ skip_update: true }}

      it { expect { subject }.not_to change { employee_balance.reload.being_processed } }
      it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }
    end
  end

  shared_examples "employee balance without any employee balances after" do
    it { expect(subject.first.being_processed).to eq false }
    it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }
  end

  context "with valid data" do
    let(:type) {{ balance_type: "addition"}}

    context "only base params given" do
      let(:options) {{}}

      it { expect { subject }.to change { Employee::Balance.count }.by(1) }
      it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }

      it { expect(subject.first.amount).to eq -100 }
      it { expect(subject.first.validity_date).to eq nil }
      it { expect(subject.first.effective_at).to be_kind_of(Time) }
      it { expect(subject.first.balance_credit_removal).to eq nil }
    end

    context "extra params given" do
      let(:amount) { 100 }

      context "and employee balance effective at is in the future" do
        let(:options) {{ effective_at: 1.year.since, resource_amount: amount }}

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }

        it { expect(subject.first.amount).to eq 100 }
        it { expect(subject.first.validity_date).to eq nil }
        it { expect(subject.first.effective_at).to be_kind_of(Time) }
        it { expect(subject.first.balance_credit_removal).to eq nil }

        it_behaves_like "employee balance without any employee balances after"
        it_behaves_like "employee balance with other employee balances after"
      end

      context "and employee balances effective_at is in the past or today" do
        context "and is today" do
          let(:options) {{ effective_at: Time.now }}

          it { expect { subject }.to change { Employee::Balance.count }.by(1) }

          it { expect(subject.first.amount).to eq 100 }
          it { expect(subject.first.validity_date).to eq nil }
          it { expect(subject.first.effective_at).to be_kind_of(Time) }
          it { expect(subject.first.balance_credit_removal).to eq nil }
        end

        context "and is in the past" do
          context "with no validity_date" do
            let(:options) {{ effective_at: Time.now - 1.year }}

            it { expect { subject }.to change { Employee::Balance.count }.by(1) }

            it { expect(subject.first.amount).to eq 100 }
            it { expect(subject.first.validity_date).to eq nil }
            it { expect(subject.first.effective_at).to be_kind_of(Time) }
            it { expect(subject.first.balance_credit_removal).to eq nil }

            it_behaves_like "employee balance without any employee balances after"
            it_behaves_like "employee balance with other employee balances after"
          end

          context "with validity_date in the past", skip: "validity date abandoned" do
            let(:options) {{ effective_at: Time.now - 1.year, validity_date: "2/4/2015" }}

            it { expect { subject }.to change { Employee::Balance.count }.by(2) }
            it { expect(subject.first.amount).to eq 100 }
            it { expect(subject.first.validity_date).to be_kind_of(Time) }
            it { expect(subject.first.effective_at).to be_kind_of(Time) }
            it { expect(subject.size).to eq 2 }
            it { expect(subject.first.balance_credit_removal).to be_kind_of(Employee::Balance) }
            it { expect(subject.last.balance_credit_additions).to include subject.first }

            it_behaves_like "employee balance without any employee balances after"
            it_behaves_like "employee balance with other employee balances after"
          end

          context "and employee balance is between addition and removal" do
            let(:options) {{ effective_at: Time.now - 2.years, validity_date: "2/4/2015"}}
            let!(:employee_balance) do
              create(:employee_balance_manual, employee: employee, time_off_category: category,
                effective_at: Time.now - 1.year, resource_amount: -amount)
            end

            it { expect { subject }.to change { employee_balance.reload.being_processed } }
            it { expect(subject.last.amount).to eq 0 }
          end
        end
      end

      context "effective date is after an existing balance effective date from another policy" do
        let(:amount) { 100 }
        let(:effective_at) { Time.now + Employee::Balance::ADDITION_OFFSET }
        let(:options) do
          {
            effective_at: effective_at,
          }
        end
        let!(:other_working_place_policy) do
          create(:employee_time_off_policy, time_off_policy: other_policy,
            effective_at: Time.zone.now - 1.month
          )
        end

        context "in the same category" do
          let(:other_policy) { create(:time_off_policy, time_off_category: category) }
          let!(:employee_balance) do
            create(:employee_balance_manual,
              employee: employee, effective_at: 1.year.ago, time_off_category: category,
              resource_amount: 100
            )
          end
          it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }
          it { expect { subject }.to_not change { employee_balance.reload.being_processed } }
          it { expect(subject.first.balance).to eq 200 }
        end

        context "in a different category" do
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
              resource_amount: 100
            )
          end

          it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }
          it { expect { subject }.to_not change { employee_balance.reload.being_processed } }
          it { expect(subject.first.balance).to eq 100 }
        end
      end

      context "time off given" do
        let(:type) {{ balance_type: "time_off" }}
        let(:options) {{ time_off_id: time_off.id }}
        let(:amount) { time_off.balance }
        let(:time_off) do
          create(:time_off, employee: employee, time_off_category: category)
        end

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }

        it { expect(subject.first.amount).to eq time_off.balance }
        it { expect(subject.first.validity_date).to be nil }
        it { expect(subject.first.effective_at).to be_kind_of(Time) }
        it { expect(subject.first.time_off).to be_kind_of(TimeOff) }
        it { expect(subject.first.time_off.id).to eq time_off.id }

        context "and there are balances between time off start and end time" do
          before { time_off.update!(start_time: Date.new(2017, 1, 1)) }
          let!(:policy_start_balance) do
            create(:employee_balance_manual,
              employee: employee, effective_at: Date.new(2017, 1, 1), balance_type: "addition",
              resource_amount: 100, time_off_category: employee_policy.time_off_category,
              being_processed: false
            )
          end

          it do
            expect { subject }.to change { policy_start_balance.reload.being_processed }.to true
          end
          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        end
      end

      context "balance credit addition given" do
        let!(:employee_balance) do
          create(:employee_balance_manual,
            time_off_category: category, employee: employee, resource_amount: 1000,
            balance_type: "addition", effective_at: 1.year.ago, validity_date: Time.now
          )
        end
        let(:type) {{ balance_type: "removal" }}
        let(:options) {{ balance_credit_additions: [employee_balance], resource_amount: 0 }}

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }
        it { expect { subject }.to_not change { employee_balance.reload.being_processed } }

        it { expect(subject.first.amount).to eq -1000 }
        it { expect(subject.first.validity_date).to be nil }
        it { expect(subject.first.effective_at).to be_kind_of(Time) }
        it { expect(subject.first.balance_credit_addition_ids).to include(employee_balance.id) }
      end
    end

    context "when addition balance for this date already exist" do
      subject do
        described_class.new(
          category.id, employee.id, Account.current.id, options
        ).call
      end

      before do
        create(:employee_balance_manual,
          employee: employee, time_off_category: employee_policy.time_off_category,
          manual_amount: 1000, balance_type: "addition",
          effective_at: employee_policy.effective_at + Employee::Balance::ADDITION_OFFSET
        )
      end

      let(:options) do
        {
          effective_at: employee_policy.effective_at + Employee::Balance::ADDITION_OFFSET,
          resource_amount: 2000,
          balance_type: "addition",
        }
      end

      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { expect(subject.first.manual_amount).to eq 1000 }
      it { expect(subject.first.resource_amount).to eq 2000 }
      it { expect(subject.first.balance_type).to eq "addition" }
    end

    context "when the balance is a reset balance" do
      let!(:contract_end) do
        create(:employee_event, employee: employee, event_type: "contract_end").effective_at
      end

      before { Employee::Balance.destroy_all }

      let(:options) { { effective_at: contract_end + 1.day + Employee::Balance::RESET_OFFSET } }
      let(:type) {{ balance_type: "reset" }}

      context "when there are no previous balances" do
        before { subject }

        it { expect(subject.first.amount).to eq 0 }
        it { expect(subject.first.balance).to eq 0 }
        it { expect(subject.first.validity_date).to eq nil }
        it { expect(subject.first.effective_at).to be_kind_of(Time) }
        it { expect(subject.first.balance_credit_removal).to eq nil }
        it { expect(subject.first.balance_credit_additions).to eq([]) }
      end

      context "when there are previous balances" do
        before do
          create(:employee_presence_policy, :with_time_entries,
            employee: employee, effective_at: 1.year.ago)
          create(:time_off,
            start_time: contract_end - 1.week, end_time: contract_end - 2.days,
            employee: employee, time_off_category: category
          )
          TimeOffs::Approve.call(TimeOff.first)
          subject
        end

        it { expect(subject.first.amount).to eq (-TimeOff.first.employee_balance.resource_amount) }
        it { expect(subject.first.balance).to eq 0 }
        it { expect(subject.first.validity_date).to eq nil }
        it { expect(subject.first.balance_credit_additions).to eq [] }
        it { expect(subject.first.balance_credit_removal).to eq nil }
      end
    end
  end

  context "with invalid data" do
    subject { CreateEmployeeBalance.new(category.id, employee.id, Account.current.id, amount).call }

    context "missing param" do
      context "missing category" do
        subject { CreateEmployeeBalance.new(nil, employee.id, Account.current.id, amount).call }

        it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
      end

      context "missing employee" do
        subject { CreateEmployeeBalance.new(category.id, nil, Account.current.id, amount).call }

        it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
      end

      context "missing account" do
        subject { CreateEmployeeBalance.new(category.id, employee.id, nil, amount).call }

        it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
      end

      context "missing amount" do
        subject do
          CreateEmployeeBalance.new(
            category.id,
            employee.id,
            Account.current.id,
            manual_amount: nil,
            resource_amount: nil
          ).call
        end

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end
    end
  end
end

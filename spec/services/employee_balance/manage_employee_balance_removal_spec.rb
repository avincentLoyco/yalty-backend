require 'rails_helper'

RSpec.describe ManageEmployeeBalanceRemoval, type: :service do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  let(:account) { create(:account) }
  let(:category) { create(:time_off_category, account: account) }
  let(:policy) { create(:time_off_policy, :with_end_date, time_off_category: category) }
  let(:employee) { create(:employee, account: account) }
  let!(:employee_time_off_policy) do
    create(:employee_time_off_policy,
      time_off_policy: policy, employee: employee, effective_at: 3.years.ago)
  end
  let!(:balance) do
    create(:employee_balance_manual,
      effective_at: 2.years.ago, validity_date: validity_date, employee: employee,
      time_off_category_id: category.id)
  end

  describe '#call' do
    subject { ManageEmployeeBalanceRemoval.new(new_date, balance).call }

    let(:validity_date) { Date.new(Time.now.year, 4, 2) + Employee::Balance::REMOVAL_OFFSET }
    let(:new_date) { Date.new(Time.now.year, 4, 2) + Employee::Balance::REMOVAL_OFFSET }

    context 'when employee balance is a balancer' do
      context 'when validity date present' do
        context 'and in past' do
          let!(:removal) do
            create(:employee_balance,
              balance_credit_additions: [balance], effective_at: removal_effective_at,
              time_off_category: category, employee: employee)
          end
          let(:removal_effective_at) { Date.new(2015, 4, 2) + Employee::Balance::REMOVAL_OFFSET }

          shared_examples 'No ther balances assigned to removal and no validity_date' do
            it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
            it { expect { subject }.to change { Employee::Balance.exists?(removal.id) }.to false }
          end

          shared_examples 'No other balances assigned to removal and validity date present' do
            before { policy.update!(years_to_effect: 3) }

            it { expect { subject }.to change { balance.reload.balance_credit_removal_id } }
            it { expect { subject }.to change { Employee::Balance.exists?(removal.id) }.to false }
          end

          shared_examples 'Other balance assigned to removal' do
            before { removal.balance_credit_additions << validity_balance }
            let(:validity_balance) do
              balance.dup.tap do |b|
                b.update!(validity_date: removal.effective_at, effective_at: Time.now - 3.years)
              end
            end

            it { expect { subject }.to_not change { removal.effective_at } }
            it { expect { subject }.to change { balance.balance_credit_removal_id } }
            it do
              expect { subject }.to change { removal.balance_credit_additions.count }.by(-1)
            end
            it do
              subject

              expect(removal.reload.balance_credit_additions).to include validity_balance
              expect(removal.reload.balance_credit_additions).to_not include balance
            end
          end

          context 'and moved to future' do
            let(:new_date) { Date.new(2017, 4, 2) + Employee::Balance::REMOVAL_OFFSET }

            it_behaves_like 'No other balances assigned to removal and validity date present'
            it_behaves_like 'Other balance assigned to removal'
          end

          context 'and moved to past' do
            let(:new_date) { Date.new(2015, 4, 2) + Employee::Balance::REMOVAL_OFFSET }

            context 'when there is already removal in new validity date' do
              let!(:new_removal) do
                create(:employee_balance_manual,
                  effective_at: new_date, employee: balance.employee,
                  time_off_category: balance.time_off_category, balance_type: 'removal'
                )
              end

              it { expect { subject }.to change { Employee::Balance.exists?(removal.id) } }
              it do
                expect { subject }.to change { new_removal.balance_credit_additions.count }.by(1)
              end
              it do
                expect { subject }.to change { balance.balance_credit_removal.id }
                  .to(new_removal.id)
              end

              it_behaves_like 'Other balance assigned to removal'
            end

            context 'when there is no removal at validity date' do
              it { expect { subject }.to change { balance.balance_credit_removal } }
              it { expect { subject }.to change { Employee::Balance.exists?(removal.id) } }

              it { expect { subject }.to_not change { Employee::Balance.count } }
              it do
                subject

                expect(balance.balance_credit_removal_id).to_not eq removal.id
                expect(balance.balance_credit_removal_id).to_not eq nil
              end

              it_behaves_like 'Other balance assigned to removal'
            end
          end

          context 'and now not present' do
            let(:new_date) { nil }

            it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
            it { expect { subject }.to change { Employee::Balance.exists?(removal.id) }.to false }

            it_behaves_like 'No ther balances assigned to removal and no validity_date'
            it_behaves_like 'Other balance assigned to removal'
          end
        end

        context 'and in future' do
          let(:validity_date) { Date.today + 3.months + 1.day + Employee::Balance::REMOVAL_OFFSET }

          context 'and moved to today or earlier' do
            let(:new_date) { Date.today + Employee::Balance::REMOVAL_OFFSET }

            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          end

          context 'and moved to future' do
            let(:new_date) do
              Date.today + 1.year + 3.months + 1.day + Employee::Balance::REMOVAL_OFFSET
            end

            context 'and previously didnt have employee balance removal' do
              it { expect { subject }.to change { Employee::Balance.count }.by(1) }
              it { expect { subject }.to change { balance.balance_credit_removal_id } }
            end

            context 'and previous had employee balance removal' do
              let!(:removal) do
                create(:employee_balance,
                  employee: employee, time_off_category: category, effective_at: validity_date,
                  balance_credit_additions: [balance])
              end

              it { expect { subject }.to change { Employee::Balance.exists?(removal.id) } }
              it { expect { subject }.to change { balance.balance_credit_removal_id } }
              it do
                subject

                expect(balance.balance_credit_removal_id).to_not eq nil
              end
            end
          end

          context 'and now not present' do
            let(:new_date) { nil }

            context 'and balance had balance credit removal' do
              let!(:removal) do
                create(:employee_balance,
                  employee: employee, time_off_category: category, effective_at: validity_date,
                  balance_credit_additions: [balance])
              end

              it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
              it { expect { subject }.to change { Employee::Balance.exists?(removal.id) } }
              it do
                expect { subject }.to change { balance.balance_credit_removal_id }.to nil
              end
            end

            context 'and balance didnt have balance credit removal' do
              it { expect { subject }.to_not change { Employee::Balance.count } }
              it { expect { subject }.to_not change { balance.balance_credit_removal_id } }
            end
          end
        end
      end

      context 'when validity date not present' do
        let(:validity_date) { nil }

        context 'and now in future' do
          let(:new_date) { Date.new(2017, 4, 2) + Employee::Balance::REMOVAL_OFFSET }

          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          it { expect { subject }.to change { balance.balance_credit_removal_id } }
        end

        context 'and now in past' do
          let(:new_date) { Date.new(2016, 4, 2) - 1.year + Employee::Balance::REMOVAL_OFFSET }

          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          it { expect { subject }.to change { balance.balance_credit_removal_id } }
        end
      end

      context 'when new validity date is the same as previous one and balance has removal' do
        before do
          create(:employee_balance_manual,
            employee: employee, time_off_category: category, effective_at: validity_date,
            balance_credit_additions: [balance], balance_type: 'removal')
        end

        it { expect { subject }.to_not change { Employee::Balance.count } }
        it { expect { subject }.to_not change { balance.reload.balance_credit_removal_id } }
      end
    end

    context 'when employee balance is a counter' do
      before do
        balance.time_off_policy.update!(
          policy_type: 'counter', amount: nil, end_day: nil, end_month: nil
        )
      end

      it { expect { subject }.to_not change { Employee::Balance.count } }
    end
  end
end

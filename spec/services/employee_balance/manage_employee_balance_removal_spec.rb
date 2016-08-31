require 'rails_helper'

RSpec.describe ManageEmployeeBalanceRemoval, type: :service do
  include_context 'shared_context_account_helper'

  let!(:balance) do
    create(:employee_balance, effective_at: Date.today - 2.years, validity_date: validity_date)
  end

  describe '#call' do
    subject { ManageEmployeeBalanceRemoval.new(new_date, balance).call }

    let(:validity_date) { Date.today - 1.day }
    let(:new_date) { Date.today }

    context 'when employee balance is a balancer' do
      context 'when validity date present' do
        context 'and in past' do
          let!(:removal) { create(:employee_balance, balance_credit_additions: [balance]) }

          shared_examples 'No ther balances assigned to removal' do
            it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
            it { expect { subject }.to change { Employee::Balance.exists?(removal.id) }.to false }
          end

          shared_examples 'Other balance assigned to removal' do
            before { removal.balance_credit_additions << validity_balance }
            let(:validity_balance) do
              balance.dup.tap do |b|
                b.update!(validity_date: removal.effective_at, effective_at: Time.now - 3.years)
              end
            end

            it { expect { subject }.to_not change { removal.reload.validity_date } }
            it do
              expect { subject }.to change { removal.reload.balance_credit_additions.count }.by(-1)
            end
            it do
              subject

              expect(removal.reload.balance_credit_additions).to include validity_balance
            end
          end

          context 'and moved to future' do
            let(:new_date) { Date.today + 1.week }

            it_behaves_like 'No ther balances assigned to removal'
            it_behaves_like 'Other balance assigned to removal'
          end

          context 'and moved to past' do
            let(:new_date) { Date.today - 2.weeks }

            context 'when there is already removal in new validity date' do
              let!(:new_removal) do
                create(:employee_balance,
                  effective_at: new_date, employee: balance.employee,
                  time_off_category: balance.time_off_category
                )
              end

              it { expect { subject }.to change { Employee::Balance.exists?(removal.id) } }
              it do
                expect { subject }.to change { new_removal.balance_credit_additions.count }.by(1)
              end
              it do
                expect { subject }.to change { balance.reload.balance_credit_removal.id }
                  .to(new_removal.id)
              end

              it_behaves_like 'Other balance assigned to removal'
            end

            context 'when there is no removal at validity date' do
              it { expect { subject }.to change { balance.reload.balance_credit_removal } }
              it { expect { subject }.to change { Employee::Balance.exists?(removal.id) } }

              it { expect { subject }.to_not change { Employee::Balance.count } }

              it_behaves_like 'Other balance assigned to removal'
            end
          end

          context 'and now not present' do
            let(:new_date) { nil }

            it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
            it { expect { subject }.to change { Employee::Balance.exists?(removal.id) }.to false }

            it_behaves_like 'No ther balances assigned to removal'
            it_behaves_like 'Other balance assigned to removal'
          end
        end

        context 'and in future' do
          let(:validity_date) { Date.today + 1.week }

          context 'and moved to today or earlier' do
            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          end

          context 'and moved to future' do
            let(:new_date) { Date.today + 1.month }

            it { expect { subject }.to_not change { Employee::Balance.count } }
          end

          context 'and now not present' do
            let(:new_date) { nil }

            it { expect { subject }.to_not change { Employee::Balance.count } }
          end
        end
      end

      context 'when validity date not present' do
        let(:validity_date) { nil }

        context 'and now in future' do
          let(:new_date) { Date.today + 1.week }

          it { expect { subject }.to_not change { Employee::Balance.count } }
        end

        context 'and now in past' do
          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        end
      end
    end

    context 'when employee balance is a counter' do
      before { balance.time_off_policy.update!(policy_type: 'counter', amount: nil) }

      it { expect { subject }.to_not change { Employee::Balance.count } }
    end
  end
end

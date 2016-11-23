require 'rails_helper'

RSpec.describe CalculateEmployeeBalanceRemovalAmount do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  describe '.call' do
    before do
      create(:employee_presence_policy, :with_time_entries,
        employee: employee, effective_at: Time.now - 1.year)
      create(:employee_time_off_policy, time_off_policy: policy, employee: employee)
      time_off.employee_balance.update!(
        manual_amount: time_off_manual, validity_date: '1/4/2016',
        balance_credit_removal: time_off_removal
      )
      removal.reload.balance_credit_additions
    end

    let!(:policy_balance) do
      create(:employee_balance_manual,
        employee: employee, time_off_category: category, validity_date: '1/4/2016',
        resource_amount: 0, manual_amount: policy_adjustment,
        effective_at: employee_policy.effective_at + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
        policy_credit_addition: true)
    end
    let(:account) { create(:account) }
    let(:category) { create(:time_off_category, account: account) }
    let(:policy) { create(:time_off_policy, :with_end_date, time_off_category: category) }
    let(:policy_adjustment) { 0 }
    let(:employee) { create(:employee, account: account) }
    let(:employee_policy) { employee.employee_time_off_policies.first }
    let!(:removal) do
      create(:employee_balance_manual,
        employee: employee, time_off_category: category,
        effective_at: '1/4/2016', balance_credit_additions: [policy_balance])
    end
    let(:time_off) do
      create(:time_off,
        employee: employee, time_off_category: category, start_time: 5.days.since,
        end_time: 1.week.since)
    end

    subject { described_class.new(removal).call }

    context 'and time off policy is a counter type' do
      before do
        time_off.employee_balance.update!(validity_date: nil)
        policy.update!(policy_type: 'counter', end_day: nil, end_month: nil, amount: nil)
        employee_policy.reload
      end

      let(:time_off_removal) { nil }

      context 'and there were previous balances' do
        context 'and their balance bigger than 0' do
          let(:time_off_manual) { 5000 }

          it { expect(subject).to eq -(5000 + time_off.balance) }
        end

        context 'and their balance smaller than 0' do
          let(:time_off_manual) { -1500 }

          it { expect(subject).to eq (1500 - time_off.balance) }
        end

        context 'and their balance equal 0' do
          let(:time_off_manual) { 960 }

          it { expect(subject).to eq 0 }
        end
      end
    end

    context 'and time off policy is a balancer type' do
      let(:time_off_removal) { removal }
      let(:time_off_manual) { 100 }

      context 'and the removal validity date is the same as the effective at' do
        let(:removal_manual_amount) { 7 }
        let!(:removal) do
          create(:employee_balance_manual,
            employee: employee, time_off_category: category, effective_at: '1/4/2016',
            validity_date: '1/4/2016',
            balance_credit_additions: [policy_balance], manual_amount: removal_manual_amount
          )
        end
        context 'when there are no other balances except addition' do
          before do
            time_off.employee_balance.destroy!
            time_off.destroy!
          end

          it do
            expect(subject).to eq (
                -(EmployeeTimeOffPolicy.first.policy_assignation_balance.resource_amount +
                  removal_manual_amount)
              )
          end

          context 'but there is a time off which starts before effective at and ends after' do
            before do
              create(:time_off,
                employee: employee, time_off_category: removal.time_off_category,
                start_time: removal.effective_at - 1.days, end_time: removal.effective_at + 2.days
              )
            end

            context 'when removal manual amount greater than time off related amount' do
              let(:policy_adjustment) { 1000 }

              it do
                expect(subject).to eq -(1000 + TimeOff.last.balance(
                  nil, removal.effective_at.end_of_day
                ) + removal_manual_amount)
              end
            end

            context 'when removal manual amount smaller than time off related amount' do
              let(:policy_adjustment) { 100 }

              it { expect(subject).to eq -7 }
            end
          end
        end

        context 'when there are no end dates, start dates and assignations in the period' do
          context 'and whole additions amount was used' do
            let(:policy_adjustment) { 100 }

            it { expect(subject).to eq (- removal_manual_amount) }
          end

          context 'and not whole addition amoount was used' do
            let(:policy_adjustment) { 2000 }

            it { expect(subject).to eq(-(2100 - time_off.balance.abs + removal_manual_amount)) }
          end
        end

        context 'when there are balances which belongs to other removal but they are smaller than 0' do
          let(:policy_adjustment) { 10000 }

          context 'and removal is not in their period' do
            let!(:new_time_off) do
              create(:time_off,
                employee: employee, time_off_category: category, start_time: '3/3/2016',
                end_time: '6/3/2016')
            end

            it '' do
              expect(subject).to eq (-( 10100 + time_off.balance + new_time_off.balance +
                removal_manual_amount)
              )

            end
          end

          context 'and removal is in their period' do
            let!(:new_time_off) do
              create(:time_off,
                employee: employee, time_off_category: category, start_time: '25/3/2016',
                end_time: '4/4/2016')
            end

            # TODO change new_time_off.balance to related
            it '' do
              expect(subject).to eq (
                -(10100 + time_off.balance +
                new_time_off.balance(nil, '1/4/2016'.to_time.end_of_day ) + removal_manual_amount)
               )
            end

            context 'when other policy addition added in the period' do
              # TODO case where end month is the same
              before { new_employee_policy.policy_assignation_balance.update!(resource_amount: 0) }
              let(:new_policy) do
                create(:time_off_policy, time_off_category: category, end_day: 1, end_month: 5)
              end
              let(:new_employee_policy) do
                create(:employee_time_off_policy, :with_employee_balance,
                  employee: employee, time_off_policy: new_policy, effective_at: '1/3/2016')
              end

              context 'and all balances amount was used' do
                let(:policy_adjustment) { 960 }

                it { expect(subject).to eq (- removal_manual_amount) }

                context 'when removal for the new policy is created' do
                  let(:time_off_manual) { 0 }

                  before do
                    new_employee_policy.policy_assignation_balance.update!(manual_amount: 5000)
                    removal.update!(resource_amount: 0)
                    new_time_off.employee_balance.update!(balance: 0)
                  end

                  let(:new_removal) do
                    create(:employee_balance_manual,
                      employee: employee, time_off_category: category, effective_at: '1/5/2016',
                      balance_credit_additions: [new_employee_policy.policy_assignation_balance])
                  end

                  subject { described_class.new(new_removal).call }

                  it { expect(subject).to eq -(5000 + new_time_off.balance + removal_manual_amount) }
                end
              end

              context 'and all balances amount wasn\'t used' do
                it do
                  expect(subject).to eq ( -( 10100 + time_off.balance +
                    new_time_off.balance(nil, '1/4/2016'.to_time.end_of_day) +
                    removal_manual_amount)
                  )
                end

                context 'when removal for the new policy is created' do
                  before do
                    new_employee_policy.policy_assignation_balance.update!(manual_amount: 1000)
                    removal.update!(
                      resource_amount:
                        -(10100 + time_off.balance + new_time_off.balance(nil, '1/4/2016'.to_time.end_of_day))
                    )
                    new_time_off.employee_balance.update!(balance: 0)
                  end

                  let(:new_removal) do
                    create(:employee_balance_manual,
                      employee: employee, time_off_category: category, effective_at: '1/5/2016',
                      balance_credit_additions: [new_employee_policy.policy_assignation_balance])
                  end

                  subject { described_class.new(new_removal).call }

                  it do
                    expect(subject).to eq ( -( 1000 +
                       new_time_off.balance('1/4/2016'.to_time.end_of_day, nil) +
                       removal_manual_amount)
                    )
                  end
                end
              end
            end
          end
        end
      end

      context 'and the removal of the validity_date is different than the effective at' do
        context 'when there are no other balances except addition' do
          before do
            time_off.employee_balance.destroy!
            time_off.destroy!
          end

          it do
            expect(subject)
              .to eq -(EmployeeTimeOffPolicy.first.policy_assignation_balance.resource_amount)
          end
        end

        context 'when there are no end dates, start dates and assignations in the period' do
          context 'and whole additions amount was used' do
            let(:policy_adjustment) { 100 }

            it { expect(subject).to eq 0 }
          end

          context 'and not whole addition amoount was used' do
            let(:policy_adjustment) { 2000 }

            it { expect(subject).to eq(-(2100 - time_off.balance.abs)) }
          end
        end

        context 'when there are balances which belongs to other removal but they are smaller than 0' do
          let(:policy_adjustment) { 10000 }

          context 'and removal is not in their period' do
            let!(:new_time_off) do
              create(:time_off,
                employee: employee, time_off_category: category, start_time: '3/3/2016',
                end_time: '6/3/2016')
            end

            it { expect(subject).to eq -(10100 + time_off.balance + new_time_off.balance) }
          end

          context 'and removal is in their period' do
            let!(:new_time_off) do
              create(:time_off,
                employee: employee, time_off_category: category, start_time: '25/3/2016',
                end_time: '4/4/2016')
            end

            # TODO change new_time_off.balance to related
            it do
              expect(subject).to eq -(
                10100 + time_off.balance + new_time_off.balance(nil, '1/4/2016'.to_time.end_of_day)
              )
            end

            context 'when other policy addition added in the period' do
              # TODO case where end month is the same
              before { new_employee_policy.policy_assignation_balance.update!(resource_amount: 0) }
              let(:new_policy) do
                create(:time_off_policy, time_off_category: category, end_day: 1, end_month: 5)
              end
              let(:new_employee_policy) do
                create(:employee_time_off_policy, :with_employee_balance,
                  employee: employee, time_off_policy: new_policy, effective_at: '1/3/2016')
              end

              context 'and all balances amount was used' do
                let(:policy_adjustment) { 960 }

                it { expect(subject).to eq 0 }

                context 'when removal for the new policy is created' do
                  let(:time_off_manual) { 0 }

                  before do
                    new_employee_policy.policy_assignation_balance.update!(manual_amount: 5000)
                    removal.update!(resource_amount: 0)
                    new_time_off.employee_balance.update!(balance: 0)
                  end

                  let(:new_removal) do
                    create(:employee_balance_manual,
                      employee: employee, time_off_category: category, effective_at: '1/5/2016',
                      balance_credit_additions: [new_employee_policy.policy_assignation_balance])
                  end

                  subject { described_class.new(new_removal).call }

                  it { expect(subject).to eq -(5000 + new_time_off.balance) }
                end
              end

              context 'and all balances amount wasn\'t used' do
                it do
                  expect(subject).to eq -(
                    10100 + time_off.balance + new_time_off.balance(nil, '1/4/2016'.to_time.end_of_day)
                  )
                end

                context 'when removal for the new policy is created' do
                  before do
                    new_employee_policy.policy_assignation_balance.update!(manual_amount: 1000)
                    removal.update!(
                      resource_amount:
                        -(10100 + time_off.balance + new_time_off.balance(nil, '1/4/2016'.to_time.end_of_day))
                    )
                    new_time_off.employee_balance.update!(balance: 0)
                  end

                  let(:new_removal) do
                    create(:employee_balance_manual,
                      employee: employee, time_off_category: category, effective_at: '1/5/2016',
                      balance_credit_additions: [new_employee_policy.policy_assignation_balance])
                  end

                  subject { described_class.new(new_removal).call }

                  it do
                    expect(subject)
                      .to eq -(1000 + new_time_off.balance('1/4/2016'.to_time.end_of_day, nil))
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

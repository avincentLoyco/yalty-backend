require 'rails_helper'

RSpec.describe ManageEmployeeBalanceAdditions, type: :service do
  include_context 'shared_context_timecop_helper'
  include_context 'shared_context_account_helper'

  subject { ManageEmployeeBalanceAdditions.new(resource).call }
  let(:employee) { create(:employee) }
  let(:category) { create(:time_off_category, account: employee.account) }
  let(:resource) do
    create(:employee_time_off_policy,
      time_off_policy: policy, effective_at: effective_at, employee: employee
    )
  end

  context 'when resource first start date in a past' do
    let(:policy) do
      create(:time_off_policy, policy_type: 'counter', amount: nil, time_off_category: category)
    end

    context 'when resource first start date in the future' do
      let(:effective_at) { 1.day.since }

      it { expect { subject }.to change { Employee::Balance.count } }
      it { expect { subject }.to_not raise_exception }
    end

    context 'and resource is a counter type' do
      let(:effective_at) { 3.years.ago }

      it { expect { subject }.to change { Employee::Balance.additions.count }.by(6) }
      it { expect { subject }.to_not change { Employee::Balance.removals.count } }

      context 'created balances params' do
        before { subject }

        it { expect(Employee::Balance.additions.map(&:amount).uniq).to eq [0] }

        it 'has valid effective_at' do
          expect(Employee::Balance.additions.pluck(:effective_at).map(&:to_date))
            .to contain_exactly(
              '1/1/2013'.to_date, '1/1/2014'.to_date, '1/1/2015'.to_date, '1/1/2016'.to_date,
              '1/1/2017'.to_date, '1/1/2018'.to_date
            )
        end
      end
    end

    context 'and resource is a balancer type' do
      let(:policy) do
        create(:time_off_policy, policy_type: 'balancer', time_off_category: category, amount: 1000)
      end

      context 'when resource first start date in the future' do
        let(:effective_at) { 1.day.since }

        it { expect { subject }.to change { Employee::Balance.count } }
        it { expect { subject }.to_not raise_exception }
      end

      context 'when resource first start date in past' do
        let(:effective_at) { 3.years.ago }

        context 'and resource policy does not have validity date' do
          let(:effective_at) { 3.years.ago }
          it { expect { subject }.to change { Employee::Balance.additions.count }.by(5) }
          it { expect { subject }.to_not change { Employee::Balance.removals.count } }
        end

        context 'and resource policy has validity date' do
          let(:years) { 1 }
          before { policy.update!(end_month: 4, end_day: 1, years_to_effect: years) }
          let(:end_day) { policy.end_day + 1 }

          context 'and years to effect eql 0' do
            let(:years) { 0 }
            let(:expected_dates) do
              [
                "#{end_day}/4/2013", "#{end_day}/4/2014", "#{end_day}/4/2015", "#{end_day}/4/2016",
                "#{end_day}/4/2017", "#{end_day}/4/2018"
              ].map(&:to_date)
            end

            it { expect { subject }.to change { Employee::Balance.additions.count }.by(5) }
            it { expect { subject }.to change { Employee::Balance.removals.count }.by(6) }

            it 'has valid validity dates' do
              subject

              expect(Employee::Balance.removals.pluck(:effective_at).map(&:to_date))
                .to match_array(expected_dates)
            end
          end

          context 'and years to effect eql 2' do
            let(:years) { 2 }
            let(:expected_dates) do
              [
                "#{end_day}/4/2015", "#{end_day}/4/2016", "#{end_day}/4/2017", "#{end_day}/4/2018",
                "#{end_day}/4/2019", "#{end_day}/4/2020", "#{end_day}/4/2021"
              ].map(&:to_date)
            end

            it { expect { subject }.to change { Employee::Balance.additions.count }.by(6) }
            it { expect { subject }.to change { Employee::Balance.removals.count }.by(7) }

            it 'has valid validity dates' do
              subject

              expect(Employee::Balance.removals.pluck(:effective_at).map(&:to_date))
                .to match_array(expected_dates)
            end
          end

          context 'effective till' do
            let(:effective_at) { 3.years.ago }

            shared_examples 'One year policy with validity date' do
              it { expect { subject }.to change { Employee::Balance.additions.count }.by(5) }
              it { expect { subject }.to change { Employee::Balance.removals.count }.by(6) }

              it 'has valid additions effective at' do
                subject

                type_offset = Employee::Balance::ADDITION_OFFSET
                additions_dates = Employee::Balance.additions.pluck(:effective_at)

                expect(additions_dates.map(&:to_date))
                  .to contain_exactly(
                    '1/1/2014'.to_date, '1/1/2015'.to_date, '1/1/2016'.to_date,
                    '1/1/2017'.to_date, '1/1/2018'.to_date
                  )
                expect(additions_dates.map { |a| a.strftime('%H:%M:%S') }.uniq)
                  .to contain_exactly("00:00:0#{type_offset}")
              end

              it 'has valid assignations effective at' do
                subject

                assignations_dates = Employee::Balance.where(balance_type: 'assignation').pluck(:effective_at)
                type_offset = Employee::Balance::ASSIGNATION_OFFSET

                expect(assignations_dates.map(&:to_date)).to contain_exactly('1/1/2013'.to_date)
                expect(assignations_dates.map { |a| a.strftime('%H:%M:%S') }.uniq)
                  .to contain_exactly("00:00:0#{type_offset}")
              end

              it 'has valid end of period effective at' do
                subject

                end_of_periods_dates = Employee::Balance.where(balance_type: 'end_of_period').pluck(:effective_at)
                type_offset = Employee::Balance::END_OF_PERIOD_OFFSET

                expect(end_of_periods_dates.map(&:to_date))
                  .to contain_exactly(
                    '1/1/2014'.to_date, '1/1/2015'.to_date, '1/1/2016'.to_date, '1/1/2017'.to_date,
                    '1/1/2018'.to_date
                  )
                expect(end_of_periods_dates.map { |a| a.strftime('%H:%M:%S') }.uniq)
                  .to contain_exactly("00:00:0#{type_offset}")
              end

              it 'has valid removal effective at' do
                subject

                type_offset = Employee::Balance::REMOVAL_OFFSET
                removals_dates = Employee::Balance.removals.pluck(:effective_at)

                expect(removals_dates.map(&:to_date))
                  .to match_array(
                    [
                      "#{end_day}/4/2014", "#{end_day}/4/2015", "#{end_day}/4/2016",
                      "#{end_day}/4/2017", "#{end_day}/4/2018", "#{end_day}/4/2019"
                    ].map(&:to_date)
                  )
                expect(removals_dates.map { |a| a.strftime('%H:%M:%S') }.uniq)
                  .to contain_exactly("00:00:0#{type_offset}")
              end
            end

            context 'and there is no policy after effective at' do
              it_behaves_like 'One year policy with validity date'
            end

            context 'when there are two employee time off policies' do
              let!(:resource) do
                create(:employee_time_off_policy,
                  employee: employee,
                  effective_at: 1.year.ago,
                  time_off_policy: create(:time_off_policy, :with_end_date, time_off_category: category))
              end
              let!(:second_etop) do
                create(:employee_time_off_policy,
                  employee: employee,
                  effective_at: Date.today,
                  time_off_policy: create(:time_off_policy, :with_end_date,
                    end_month: 5, time_off_category: category))
              end

              before { subject }

              let(:end_of_periods) do
                Employee::Balance
                  .where(balance_type: 'end_of_period')
                  .order(:effective_at)
                  .pluck(:effective_at)
              end

              it { expect(Employee::Balance.where(balance_type: 'assignation').count).to eq 2 }
              it 'has valid end of period balances' do
                end_of_periods =
                  Employee::Balance.where(balance_type: 'end_of_period').order(:effective_at)

                expect(end_of_periods.count).to eq 3
                expect(end_of_periods.pluck(:effective_at).map(&:to_date)).to eq(
                  ['1/1/2016', '1/1/2017', '1/1/2018'].map(&:to_date)
                )
                expect(end_of_periods.pluck(:validity_date).map(&:to_date)).to eq(
                  ['2/4/2016', '2/5/2017', '2/5/2018'].map(&:to_date)
                )
              end
            end

            context 'and there is an employee time off policy after effective at' do
              context 'and it does not have reset policy assigned' do
                let!(:next_employee_time_off_policy) do
                  create(:employee_time_off_policy,
                    employee: employee, effective_at: 2.years.ago + 1.day,
                    time_off_policy: policy,
                  )
                end

                context 'in the past' do
                  it { expect { subject }.to change { Employee::Balance.additions.count }.by(5) }
                  it { expect { subject }.to change { Employee::Balance.removals.count }.by(6) }

                  it 'has valid additions effective at' do
                    subject

                    expect(Employee::Balance.additions.pluck(:effective_at).map(&:to_date))
                      .to contain_exactly(
                        '1/1/2014'.to_date, '1/1/2015'.to_date,
                        '1/1/2016'.to_date, '1/1/2017'.to_date, '1/1/2018'.to_date
                      )
                  end

                  it 'has valid removal effective at' do
                    subject

                    expect(Employee::Balance.removals.pluck(:effective_at).map(&:to_date))
                      .to contain_exactly(
                          "#{end_day}/4/2014".to_date, "#{end_day}/4/2015".to_date,
                          "#{end_day}/4/2016".to_date, "#{end_day}/4/2017".to_date,
                          "#{end_day}/4/2018".to_date, "#{end_day}/4/2019".to_date
                      )
                  end
                end

                context 'in the future' do
                  before do
                    next_employee_time_off_policy.update!(effective_at: 1.year.since + 1.day)
                  end

                  it { expect { subject }.to change { Employee::Balance.additions.count }.by(5) }
                  it { expect { subject }.to change { Employee::Balance.removals.count }.by(6) }

                  it 'has valid additions effective at' do
                    subject

                    expect(Employee::Balance.additions.pluck(:effective_at).map(&:to_date))
                      .to contain_exactly(
                        '1/1/2014'.to_date, '1/1/2015'.to_date,
                        '1/1/2016'.to_date, '1/1/2017'.to_date, '1/1/2018'.to_date
                      )
                  end

                  it 'has valid removal effective at' do
                    subject

                    expect(Employee::Balance.removals.pluck(:effective_at).map(&:to_date))
                      .to match_array(
                        [
                          "#{end_day}/4/2014", "#{end_day}/4/2015", "#{end_day}/4/2016",
                          "#{end_day}/4/2017", "#{end_day}/4/2018", "#{end_day}/4/2019"
                        ].map(&:to_date))
                  end
                end
              end

              context 'and it has reset policy assigned' do
                before do
                  resource
                  create(:employee_event,
                    employee: employee, event_type: 'contract_end', effective_at: 1.week.ago)
                end

                let(:policy_removal) do
                  EmployeeTimeOffPolicy.with_reset.first.policy_assignation_balance
                end

                context 'and there no rehired date with new etop after it' do
                  before { subject }

                  it 'has valid balances effective at' do
                    expect(Employee::Balance.order(:effective_at).pluck(:effective_at).map(&:to_date))
                      .to match_array(
                        %w(
                            1/1/2013 1/1/2014 1/1/2014 2/4/2014 1/1/2015 1/1/2015 2/4/2015
                            26/12/2015
                          ).map(&:to_date)
                      )
                  end

                  it { expect(policy_removal.balance_credit_additions.size).to eq 1 }
                end

                context 'and there is rehired date with the new etop after it' do
                  before do
                    create(:employee_event,
                      employee: employee, event_type: 'hired', effective_at: 1.year.since + 1.week)
                    create(:employee_time_off_policy,
                      employee: employee, time_off_policy: policy, effective_at: 1.year.since + 1.week)
                    subject
                  end

                  it 'has valid balances effective at' do
                    expect(Employee::Balance.order(:effective_at).pluck(:effective_at).map(&:to_date))
                      .to match_array(
                        %w(
                            1/1/2013 1/1/2014 1/1/2014 2/4/2014 1/1/2015 1/1/2015 2/4/2015
                            26/12/2015 8/1/2017 1/1/2018 1/1/2018 2/4/2018 2/4/2019
                          ).map(&:to_date)
                      )
                  end

                  it { expect(policy_removal.balance_credit_additions.size).to eq 1 }
                end
              end
            end
          end
        end

        context 'created balances params' do
          before { subject }

          it { expect(Employee::Balance.additions.map(&:amount).uniq).to eq [1000] }

          it 'has valid effective_at' do
            expect(Employee::Balance.additions.pluck(:effective_at).map(&:to_date))
              .to contain_exactly(
                '1/1/2014'.to_date, '1/1/2015'.to_date, '1/1/2016'.to_date,
                '1/1/2017'.to_date, '1/1/2018'.to_date
              )
          end
        end
      end
    end
  end
end

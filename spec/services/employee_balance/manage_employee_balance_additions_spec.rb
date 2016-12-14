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
      let(:effective_at) { Time.zone.now + 1.day }

      it { expect { subject }.to change { Employee::Balance.count } }
      it { expect { subject }.to_not raise_exception }
    end

    context 'and resource is a counter type' do
      let(:effective_at) { Time.zone.now - 3.years }

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
        let(:effective_at) { Time.zone.now + 1.day }

        it { expect { subject }.to change { Employee::Balance.count } }
        it { expect { subject }.to_not raise_exception }
      end

      context 'when resource first start date in past' do
        let(:effective_at) { Time.zone.now - 3.years }

        context 'and resource policy does not have validity date' do
          let(:effective_at) { Time.zone.now - 3.years }

          it { expect { subject }.to change { Employee::Balance.additions.count }.by(6) }
          it { expect { subject }.to_not change { Employee::Balance.removals.count } }
        end

        context 'and resource policy has validity date' do
          let(:years) { 1 }
          before { policy.update!(end_month: 4, end_day: 1, years_to_effect: years) }

          context 'and years to effect eql 0' do
            let(:years) { 0 }
            let(:expected_dates) do
              ['1/4/2013', '1/4/2014', '1/4/2015', '1/4/2016', '1/4/2017', '1/4/2018'].map &:to_date
            end

            it { expect { subject }.to change { Employee::Balance.additions.count }.by(6) }
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
                '1/4/2015', '1/4/2016', '1/4/2017', '1/4/2018', '1/4/2019', '1/4/2020', '1/4/2021'
              ].map(&:to_date)
            end

            it { expect { subject }.to change { Employee::Balance.additions.count }.by(7) }
            it { expect { subject }.to change { Employee::Balance.removals.count }.by(7) }

            it 'has valid validity dates' do
              subject

              expect(Employee::Balance.removals.pluck(:effective_at).map(&:to_date))
                .to match_array(expected_dates)
            end
          end

          context 'effective till' do
            let(:effective_at) { Time.now - 3.years }

            shared_examples 'One year policy with validity date' do
              it { expect { subject }.to change { Employee::Balance.additions.count }.by(6) }
              it { expect { subject }.to change { Employee::Balance.removals.count }.by(6) }

              it 'has valid additions effective at' do
                subject

                expect(Employee::Balance.additions.pluck(:effective_at).map(&:to_date))
                  .to contain_exactly(
                    '1/1/2013'.to_date, '1/1/2014'.to_date, '1/1/2015'.to_date, '1/1/2016'.to_date,
                    '1/1/2017'.to_date, '1/1/2018'.to_date
                  )
              end

              it 'has valid removal effective at' do
                subject

                expect(Employee::Balance.removals.pluck(:effective_at).map(&:to_date))
                  .to match_array(
                    [
                      '1/4/2014', '1/4/2015', '1/4/2016', '1/4/2017', '1/4/2018', '1/4/2019'
                    ].map(&:to_date)
                  )
              end
            end

            context 'and there is no policy after effective at' do
              it_behaves_like 'One year policy with validity date'
            end

            context 'and there is an employee time off policy after effective at' do
              let!(:next_employee_time_off_policy) do
                create(:employee_time_off_policy,
                  employee: employee, effective_at: Time.now - 2.years + 1.day,
                  time_off_policy: policy,
                )
              end

              context 'in the past' do
                it { expect { subject }.to change { Employee::Balance.additions.count }.by(6) }
                it { expect { subject }.to change { Employee::Balance.removals.count }.by(6) }

                it 'has valid additions effective at' do
                  subject

                  expect(Employee::Balance.additions.pluck(:effective_at).map(&:to_date))
                    .to contain_exactly('1/1/2013'.to_date, '1/1/2014'.to_date, '1/1/2015'.to_date, '1/1/2016'.to_date,
                    '1/1/2017'.to_date, '1/1/2018'.to_date)
                end

                it 'has valid removal effective at' do
                  subject

                  expect(Employee::Balance.removals.pluck(:effective_at).map(&:to_date))
                    .to contain_exactly('1/4/2014'.to_date, '1/4/2015'.to_date, '1/4/2016'.to_date,
                    '1/4/2017'.to_date, '1/4/2018'.to_date, '1/4/2019'.to_date)
                end
              end

              context 'in the future' do
                before do
                  next_employee_time_off_policy.update!(effective_at: Time.now + 1.year + 1.day)
                end

                it { expect { subject }.to change { Employee::Balance.additions.count }.by(6) }
                it { expect { subject }.to change { Employee::Balance.removals.count }.by(6) }

                it 'has valid additions effective at' do
                  subject

                  expect(Employee::Balance.additions.pluck(:effective_at).map(&:to_date))
                    .to contain_exactly(
                      '1/1/2013'.to_date, '1/1/2014'.to_date, '1/1/2015'.to_date, '1/1/2016'.to_date,
                      '1/1/2017'.to_date, '1/1/2018'.to_date
                    )
                end

                it 'has valid removal effective at' do
                  subject

                  expect(Employee::Balance.removals.pluck(:effective_at).map(&:to_date))
                    .to match_array(
                      ['1/4/2014', '1/4/2015', '1/4/2016', '1/4/2017', '1/4/2018', '1/4/2019'].map(&:to_date))
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
                '1/1/2013'.to_date, '1/1/2014'.to_date, '1/1/2015'.to_date, '1/1/2016'.to_date,
                '1/1/2017'.to_date, '1/1/2018'.to_date
              )
          end
        end
      end
    end
  end
end

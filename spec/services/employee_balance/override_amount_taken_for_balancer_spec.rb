require 'rails_helper'

RSpec.describe OverrideAmountTakenForBalancer do
  subject { described_class.new(periods, employee.contract_periods).call }

  let(:employee) { create(:employee) }
  let(:periods) do
    [
      {
        'type': 'balancer',
        'start_date': '2016-10-10',
        'validity_date': nil,
        'amount_taken': 1000,
        'period_result': 7000,
        'balance': 7000
      }
    ]
  end

  context 'when periods type is not balancer' do
    before { periods.first[:type] = 'counter' }

    it { expect(subject).to eq periods }
  end

  context 'when periods type is balancer' do
    context 'and it have validity date' do
      before { periods.first[:validity_date] = '2016-10-10' }

      it { expect(subject).to eq periods }
    end

    context 'and it does not have validity date' do
      context 'when there is no next period' do
        it { expect(subject).to eq periods }
      end

      context 'when there is next and current period' do
        before { periods.push(current_period, next_period) }

        let(:current_period) do
          {
            'type': 'balancer',
            'start_date': '2017-01-01',
            'validity_date': nil,
            'amount_taken': 2000,
            'period_result': 8000,
            'balance': 8000,
          }
        end
        let(:next_period) do
          {
            'type': 'balancer',
            'start_date': '2018-01-01',
            'validity_date': nil,
            'amount_taken': 0,
            'period_result': 10000,
            'balance': 18000
          }
        end

        context 'when next period amount taken is greater than 0' do
          it 'should take whole amount from active period and rest from the current one' do
            expect(subject).to eq([
              {
                'type': 'balancer',
                'start_date': '2016-10-10',
                'validity_date': nil,
                'amount_taken': 8000,
                'period_result': 0,
                'balance': 7000
              },
              {
                'type': 'balancer',
                'start_date': '2017-01-01',
                'validity_date': nil,
                'amount_taken': 2000,
                'period_result': 8000,
                'balance': 8000,
              },
              {
                'type': 'balancer',
                'start_date': '2018-01-01',
                'validity_date': nil,
                'amount_taken': 0,
                'period_result': 10000,
                'balance': 18000
              }
            ])
          end
        end

        context 'when next period amount taken is 0' do
          before { current_period[:amount_taken] = 0 }

          context 'and first period period result is 0' do
            before do
              periods.first[:period_result] = 0
              periods.first[:balance] = 0
              next_period[:balance] = 16000
            end

            it 'should take amount from the current period' do
              expect(subject).to eq([
                {
                  'type': 'balancer',
                  'start_date': '2016-10-10',
                  'validity_date': nil,
                  'amount_taken': 1000,
                  'period_result': 0,
                  'balance': 0
                },
                {
                  'type': 'balancer',
                  'start_date': '2017-01-01',
                  'validity_date': nil,
                  'amount_taken': 2000,
                  'period_result': 6000,
                  'balance': 8000,
                },
                {
                  'type': 'balancer',
                  'start_date': '2018-01-01',
                  'validity_date': nil,
                  'amount_taken': 0,
                  'period_result': 10000,
                  'balance': 16000
                }
              ])
            end
          end

          context 'and first period period result is greater than 0' do
            context 'when only active balance amount used' do
              it 'should not take amount from the active period' do
                expect(subject).to eq([
                  {
                    'type': 'balancer',
                    'start_date': '2016-10-10',
                    'validity_date': nil,
                    'amount_taken': 8000,
                    'period_result': 0,
                    'balance': 7000
                  },
                  {
                    'type': 'balancer',
                    'start_date': '2017-01-01',
                    'validity_date': nil,
                    'amount_taken': 0,
                    'period_result': 8000,
                    'balance': 8000,
                  },
                  {
                    'type': 'balancer',
                    'start_date': '2018-01-01',
                    'validity_date': nil,
                    'amount_taken': 0,
                    'period_result': 10000,
                    'balance': 18000
                  }
                ])
              end
            end

            context 'when all period amount is used' do
              before do
                next_period[:amount_taken] = 1000
                next_period[:period_result] = 9000
                next_period[:balance] = 9000
              end

              it 'should take amount from active and current period and not change amount of the next' do
                expect(subject).to eq([
                  {
                    'type': 'balancer',
                    'start_date': '2016-10-10',
                    'validity_date': nil,
                    'amount_taken': 8000,
                    'period_result': 0,
                    'balance': 7000
                  },
                  {
                    'type': 'balancer',
                    'start_date': '2017-01-01',
                    'validity_date': nil,
                    'amount_taken': 8000,
                    'period_result': 0,
                    'balance': 8000,
                  },
                  {
                    'type': 'balancer',
                    'start_date': '2018-01-01',
                    'validity_date': nil,
                    'amount_taken': 1000,
                    'period_result': 9000,
                    'balance': 9000
                  }
                ])
              end
            end

            context 'when last period balance is smaller than 0' do
              before do
                next_period[:amount_taken] = 10000
                next_period[:period_result] = 0
                next_period[:balance] = -1000
              end

              it 'should take all period results amount' do
                expect(subject).to eq([
                  {
                    'type': 'balancer',
                    'start_date': '2016-10-10',
                    'validity_date': nil,
                    'amount_taken': 8000,
                    'period_result': 0,
                    'balance': 7000
                  },
                  {
                    'type': 'balancer',
                    'start_date': '2017-01-01',
                    'validity_date': nil,
                    'amount_taken': 8000,
                    'period_result': 0,
                    'balance': 8000,
                  },
                  {
                    'type': 'balancer',
                    'start_date': '2018-01-01',
                    'validity_date': nil,
                    'amount_taken': 10000,
                    'period_result': 0,
                    'balance': -1000
                  }
                ])
              end
            end
          end
        end
      end
    end
  end
end

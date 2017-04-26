require 'rails_helper'

RSpec.describe API::V1::EmployeeBalanceOverviewsController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let!(:employee) { create(:employee, account: account) }
  let(:vacation_category) { create(:time_off_category, account: Account.current, name: 'vacation') }
  let(:vacation_balancer_policy_A_amount) { 100 }
  let(:vacation_balancer_policy_A) do
    create(:time_off_policy, :with_end_date, time_off_category: vacation_category,
      amount: vacation_balancer_policy_A_amount
    )
  end

  subject(:create_policy_balances) do
    EmployeeTimeOffPolicy.order(:effective_at).map do |etop|
      ManageEmployeeBalanceAdditions.new(etop).call
    end
  end

  subject(:update_balances) do
    Employee::Balance.order(:effective_at).map { |balance| UpdateEmployeeBalance.new(balance).call }
  end

  before do
    presence_days.map do |presence_day|
      create(:time_entry, presence_day: presence_day, start_time: '00:00', end_time: '24:00')
    end
  end

  let(:presence_policy) { create(:presence_policy, account: account) }
  let(:presence_days)  do
    [1,2,3,4,5,6,7].map do |i|
      create(:presence_day, order: i, presence_policy: presence_policy)
    end
  end

  let!(:epp) do
    create(:employee_presence_policy,
      presence_policy: presence_policy,
      employee: employee,
      effective_at: Date.today - 3.years
    )
  end
  let(:vacation_policy_A_assignation_date) { Time.now }
  let(:vacation_policy_A_assignation) do
    create(:employee_time_off_policy,
      employee: employee, effective_at: vacation_policy_A_assignation_date,
      time_off_policy: vacation_balancer_policy_A
    )
  end

  describe 'GET #show' do
    let(:employee_id) { employee.id }
    subject { get :show, employee_id: employee_id }

    context 'when there are many categories' do
      before { vacation_policy_A_assignation }

      context' and one category policy is  counter type and the other is balancer type' do
        let!(:emergency_category) do
          create(:time_off_category, account: Account.current, name: 'emergency')
        end
        let(:emergency_counter_policy) do
           create(:time_off_policy, :as_counter, time_off_category: emergency_category)
        end
        let(:emergency_policy_assignation_date) { Time.now }
        let!(:emergency_policy_assignation) do
          create(:employee_time_off_policy,
            employee: employee, effective_at: emergency_policy_assignation_date,
            time_off_policy: emergency_counter_policy
          )
        end
        before { create_policy_balances }

        it do
          subject
          expect(JSON.parse(response.body)).to eq(
            [
              {
                'employee' => employee_id,
                'category' => "emergency",
                'periods' =>
                  [
                      {
                        'type' => "counter",
                        'start_date' => '2016-01-01',
                        'validity_date' => nil,
                        'amount_taken' => 0,
                        'period_result' => 0,
                        'balance' => 0
                      },
                      {
                        'type' => "counter",
                        'start_date' => '2017-01-01',
                        'validity_date' => nil,
                        'amount_taken' => 0,
                        'period_result' => 0,
                        'balance' => 0
                      }
                  ]
              },
              {
                'employee' => employee_id,
                'category' => "vacation",
                'periods' =>
                  [
                      {
                        'type' => "balancer",
                        'start_date' => '2016-01-01',
                        'validity_date' => '2017-04-01',
                        'amount_taken' => 0,
                        'period_result' => vacation_balancer_policy_A_amount,
                        'balance' => vacation_balancer_policy_A_amount
                      },
                      {
                        'type' => "balancer",
                        'start_date' => '2017-01-01',
                        'validity_date' => '2018-04-01',
                        'amount_taken' => 0,
                        'period_result' => vacation_balancer_policy_A_amount,
                        'balance' => vacation_balancer_policy_A_amount
                      }
                  ]
              }
            ]
          )
        end

        context 'and both have time offs ' do
          before do
            vacation_policy_A_assignation
            create(:time_off, start_time: Time.zone.parse('1/2/2016 00:00:00'),
              end_time: Time.zone.parse('1/2/2016 02:30:00'), employee: employee,
              time_off_category: vacation_category
            )
            create(:time_off, start_time: Time.zone.parse('1/2/2016 05:00:00'),
              end_time: Time.zone.parse('1/2/2016 07:30:00'), employee: employee,
              time_off_category: emergency_category
            )
            create_policy_balances
            update_balances
            subject
          end

          it do
            expect(JSON.parse(response.body)).to eq(
              [
                {
                  'employee' => employee_id,
                  'category' => "emergency",
                  'periods' =>
                    [
                        {
                          'type' => "counter",
                          'start_date' => '2016-01-01',
                          'validity_date' => nil,
                          'amount_taken' => 150,
                          'period_result' => -150,
                          'balance' => -150
                        },
                        {
                          'type' => "counter",
                          'start_date' => '2017-01-01',
                          'validity_date' => nil,
                          'amount_taken' => 0,
                          'period_result' => 0,
                          'balance' => 0
                        },
                    ]
                },
                {
                  'employee' => employee_id,
                  'category' => "vacation",
                  'periods' =>
                    [
                        {
                          'type' => "balancer",
                          'start_date' => '2016-01-01',
                          'validity_date' => '2017-04-01',
                          'amount_taken' => 100,
                          'period_result' => 0,
                          'balance' => -50
                        },
                        {
                          'type' => "balancer",
                          'start_date' => '2017-01-01',
                          'validity_date' => '2018-04-01',
                          'amount_taken' => 50,
                          'period_result' => 50,
                          'balance' => 50
                        },
                    ]
                }
              ]
            )
          end

        end
      end
      context 'when there are no categories' do
        before do
          TimeOffCategory.destroy_all
          subject
        end

        it do
          expect(JSON.parse(response.body)).to eq([])
        end
      end
    end

    context 'when in the current period there are no assignations but there are in the next period' do
      let(:vacation_policy_A_assignation_date) { Time.now + 1.year }

      context ' and next period balances exist already' do
        before do
          vacation_policy_A_assignation
          create_policy_balances
          subject
        end

        it do
          expect(JSON.parse(response.body)).to eq(
            [
              {
                'employee' => employee_id,
                'category' => "vacation",
                'periods' => [
                    {
                      'type' => "balancer",
                      'start_date' => '2017-01-01',
                      'validity_date' => '2018-04-01',
                      'amount_taken' => 0,
                      'period_result' => vacation_balancer_policy_A_amount,
                      'balance' => vacation_balancer_policy_A_amount
                    }
                ]
              }
            ]
          )
        end
      end

      context ' and next period balances does not exist already' do
        before do
          vacation_policy_A_assignation
          subject
        end

        it do
          expect(JSON.parse(response.body)).to eq(
            [
              {
                'employee' => employee_id,
                'category' => "vacation",
                'periods' => []
              }
            ]
          )
        end
      end
    end

    context 'balancer type' do
      before { vacation_policy_A_assignation }

      context 'when there is contract end' do
        before do
          create(:employee_event,
            event_type: 'contract_end', effective_at: contract_end_date, employee: employee)
        end

        context 'and balances have validity date' do
          before { create_policy_balances }

          context 'and in contract end in next period' do
            let(:contract_end_date) { '1.3.2017' }

            it do
              update_balances
              subject
              expect(JSON.parse(response.body)).to eq(
                [
                  {
                    'employee' => employee_id,
                    'category' => "vacation",
                    'periods' => [
                        {
                          'type' => "balancer",
                          'start_date' => '2016-01-01',
                          'validity_date' => '2017-03-01',
                          'amount_taken' => 0,
                          'period_result' => vacation_balancer_policy_A_amount,
                          'balance' => vacation_balancer_policy_A_amount
                        },
                        {
                          'type' => "balancer",
                          'start_date' => '2017-01-01',
                          'validity_date' => '2017-03-01',
                          'amount_taken' => 0,
                          'period_result' => vacation_balancer_policy_A_amount,
                          'balance' => 2 * (vacation_balancer_policy_A_amount)
                        }
                    ]
                  }
                ]
              )
            end
          end

          context 'and contract end in current period' do
            context 'and balances have validity_date' do
              context 'and policy amount not used' do
                let(:contract_end_date) { '1.3.2016' }

                it do
                  update_balances
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        'employee' => employee_id,
                        'category' => "vacation",
                        'periods' => [
                            {
                              'type' => "balancer",
                              'start_date' => '2016-01-01',
                              'validity_date' => '2016-03-01',
                              'amount_taken' => 0,
                              'period_result' => vacation_balancer_policy_A_amount,
                              'balance' => vacation_balancer_policy_A_amount
                            }
                        ]
                      }
                    ]
                  )
                end
              end

              context 'and there is next period after contract end' do
                let(:vacation_policy_A_assignation_date) { 1.year.ago }
                let(:contract_end_date) { '1.12.2015' }

                before do
                  create(:employee_event,
                    event_type: 'hired', employee: employee, effective_at: '1/2/2016')
                  reassignation_etop =
                    create(:employee_time_off_policy, :with_employee_balance,
                      employee: employee, effective_at: '1/2/2016',
                      time_off_policy: vacation_balancer_policy_A
                    )
                  UpdateEmployeeBalance.new(
                    reassignation_etop.policy_assignation_balance,
                    resource_amount: 0, manual_amount: 100,
                    validity_date: '2/4/2017'.to_date + Employee::Balance::REMOVAL_OFFSET
                  ).call
                  ManageEmployeeBalanceAdditions.new(reassignation_etop).call
                  update_balances
                end

                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        'employee' => employee_id,
                        'category' => "vacation",
                        'periods' => [
                            {
                              'type' => "balancer",
                              'start_date' => '2015-01-01',
                              'validity_date' => '2015-12-01',
                              'amount_taken' => 0,
                              'period_result' => 100,
                              'balance' => 100
                            },
                            {
                              'type' => "balancer",
                              'start_date' => '2016-02-01',
                              'validity_date' => '2017-04-01',
                              'amount_taken' => 0,
                              'period_result' => 100,
                              'balance' => 100
                            }
                        ]
                      }
                    ]
                  )
                end
              end
            end

            context 'and policy amount used' do
              let(:contract_end_date) { '1.3.2017' }
              before do
                create(:time_off, start_time: Time.zone.parse('1/2/2017 00:30:00'),
                  end_time: end_time_hour, employee: employee,
                  time_off_category: vacation_category
                )
                update_balances
              end

              context ' partialy' do
                let(:end_time_hour) { Time.zone.parse('1/2/2017 01:30:00') }

                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        'employee' => employee_id,
                        'category' => "vacation",
                        'periods' => [
                            {
                              'type' => "balancer",
                              'start_date' => '2016-01-01',
                              'validity_date' => '2017-03-01',
                              'amount_taken' => 60,
                              'period_result' => vacation_balancer_policy_A_amount - 60,
                              'balance' => vacation_balancer_policy_A_amount
                            },
                            {
                              'type' => "balancer",
                              'start_date' => '2017-01-01',
                              'validity_date' => '2017-03-01',
                              'amount_taken' => 0,
                              'period_result' => vacation_balancer_policy_A_amount,
                              'balance' => vacation_balancer_policy_A_amount + 40
                            }
                        ]
                      }
                    ]
                  )
                end
              end

              context ' whole' do
                let(:end_time_hour) { Time.zone.parse('1/2/2017 04:30:00') }

                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        'employee' => employee_id,
                        'category' => "vacation",
                        'periods' => [
                            {
                              'type' => "balancer",
                              'start_date' => '2016-01-01',
                              'validity_date' => '2017-03-01',
                              'amount_taken' => 100,
                              'period_result' => 0,
                              'balance' => 100
                            },
                            {
                              'type' => "balancer",
                              'start_date' => '2017-01-01',
                              'validity_date' => '2017-03-01',
                              'amount_taken' => 100,
                              'period_result' => 0,
                              'balance' => -40
                            }
                        ]
                      }
                    ]
                  )
                end
              end
            end
          end
        end

        context 'and balances does not have validity date' do
          let(:vacation_policy_A_assignation_date) { '1/1/2015' }
          let(:contract_end_date) { '1.6.2016' }
          let(:vacation_balancer_policy_A) do
            create(:time_off_policy, time_off_category: vacation_category, amount: 100)
          end

          context 'contract end in next period' do
            before { vacation_policy_A_assignation }

            context 'and there are time offs' do
              before do
                create(:time_off,
                  employee: employee, time_off_category: vacation_category,
                  start_time: Time.zone.parse('1/1/2016 07:30:00'), end_time: end_time)
                create_policy_balances
                update_balances
              end

              context 'and whole amount used' do
                context 'only from active' do
                  let(:end_time) { Time.zone.parse('1/1/2016 11:30:00') }

                  it do
                    subject
                    expect(JSON.parse(response.body)).to eq(
                      [
                        {
                          'employee' => employee_id,
                          'category' => "vacation",
                          'periods' => [
                              {
                                'type' => "balancer",
                                'start_date' => '2016-01-01',
                                'validity_date' => nil,
                                'amount_taken' => 100,
                                'period_result' => 0,
                                'balance' => -40
                              }
                          ]
                        }
                      ]
                    )
                  end
                end

                context 'from current and active' do
                  let(:end_time) { Time.zone.parse('1/1/2016 8:30:00') }

                  it do
                    subject
                    expect(JSON.parse(response.body)).to eq(
                      [
                        {
                          'employee' => employee_id,
                          'category' => "vacation",
                          'periods' => [
                              {
                                'type' => "balancer",
                                'start_date' => '2015-01-01',
                                'validity_date' => nil,
                                'amount_taken' => 60,
                                'period_result' => 40,
                                'balance' => 100
                              },
                              {
                                'type' => "balancer",
                                'start_date' => '2016-01-01',
                                'validity_date' => nil,
                                'amount_taken' => 0,
                                'period_result' => 100,
                                'balance' => 140
                              }
                          ]
                        }
                      ]
                    )
                  end
                end
              end

              context 'and not whole active period amount used' do
                let(:end_time) { Time.zone.parse('1/1/2016 10:30:00') }

                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        'employee' => employee_id,
                        'category' => "vacation",
                        'periods' => [
                            {
                              'type' => "balancer",
                              'start_date' => '2016-01-01',
                              'validity_date' => nil,
                              'amount_taken' => 80,
                              'period_result' => 20,
                              'balance' => 20
                            }
                        ]
                      }
                    ]
                  )
                end
              end
            end

            context 'and there are no time offs' do
              before do
                create_policy_balances
                update_balances
              end

              it do
                subject
                expect(JSON.parse(response.body)).to eq(
                  [
                    {
                      'employee' => employee_id,
                      'category' => "vacation",
                      'periods' => [
                          {
                            'type' => "balancer",
                            'start_date' => '2015-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 100,
                            'balance' => 100
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2016-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 100,
                            'balance' => 200
                          }
                      ]
                    }
                  ]
                )
              end
            end
          end

          context 'contract end in current period' do
            let(:vacation_policy_A_assignation_date) { '1/1/2014' }
            let(:contract_end_date) { '1.12.2015' }

            before do
              vacation_policy_A_assignation
              create(:employee_event,
                event_type: 'hired', employee: employee, effective_at: '1/2/2016')
              create(:employee_time_off_policy, :with_employee_balance,
                employee: employee, effective_at: '1/2/2016',
                time_off_policy: vacation_balancer_policy_A
              )
            end

            context 'and no time offs' do
              before do
                create_policy_balances
                update_balances
              end

              it do
                subject
                expect(JSON.parse(response.body)).to eq(
                  [
                    {
                      'employee' => employee_id,
                      'category' => "vacation",
                      'periods' => [
                          {
                            'type' => "balancer",
                            'start_date' => '2014-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 100,
                            'balance' => 100
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2015-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 100,
                            'balance' => 200
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2016-02-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 100,
                            'balance' => 100
                          }
                      ]
                    }
                  ]
                )
              end
            end

            context 'and there is time offs in previous periods' do
              before do
                create(:time_off,
                  employee: employee, time_off_category: vacation_category,
                  start_time: Time.zone.parse('1/1/2015 07:30:00'), end_time: end_time)
              end

              context 'and not whole period amount used' do
                let(:end_time) { Time.zone.parse('1/1/2015 8:30:00') }

                before do
                  create_policy_balances
                  update_balances
                end


                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        'employee' => employee_id,
                        'category' => "vacation",
                        'periods' => [
                            {
                              'type' => "balancer",
                              'start_date' => '2014-01-01',
                              'validity_date' => nil,
                              'amount_taken' => 60,
                              'period_result' => 40,
                              'balance' => 100
                            },
                            {
                              'type' => "balancer",
                              'start_date' => '2015-01-01',
                              'validity_date' => nil,
                              'amount_taken' => 0,
                              'period_result' => 100,
                              'balance' => 140
                            },
                            {
                              'type' => "balancer",
                              'start_date' => '2016-02-01',
                              'validity_date' => nil,
                              'amount_taken' => 0,
                              'period_result' => 100,
                              'balance' => 100
                            }
                        ]
                      }
                    ]
                  )
                end
              end

              context 'and whole period amount used' do
                let(:end_time) { Time.zone.parse('1/1/2015 9:30:00') }

                before do
                  create_policy_balances
                  update_balances
                end

                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        'employee' => employee_id,
                        'category' => "vacation",
                        'periods' => [
                            {
                              'type' => "balancer",
                              'start_date' => '2015-01-01',
                              'validity_date' => nil,
                              'amount_taken' => 20,
                              'period_result' => 80,
                              'balance' => 80
                            },
                            {
                              'type' => "balancer",
                              'start_date' => '2016-02-01',
                              'validity_date' => nil,
                              'amount_taken' => 0,
                              'period_result' => 100,
                              'balance' => 100
                            }
                        ]
                      }
                    ]
                  )
                end
              end

              context 'and all active periods amount used' do
                let(:end_time) { Time.zone.parse('1/1/2015 11:30:00') }

                before do
                  create_policy_balances
                  update_balances
                end

                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        'employee' => employee_id,
                        'category' => "vacation",
                        'periods' => [
                            {
                              'type' => "balancer",
                              'start_date' => '2016-02-01',
                              'validity_date' => nil,
                              'amount_taken' => 0,
                              'period_result' => 100,
                              'balance' => 100
                            }
                        ]
                      }
                    ]
                  )
                end
              end
            end

            context 'and there is time off in active period' do
              before do
                create(:employee_presence_policy,
                  presence_policy: presence_policy, employee: employee, effective_at: '1/2.2016')
                create(:time_off,
                  employee: employee, time_off_category: vacation_category,
                  start_time: Time.zone.parse('1/2/2016 07:30:00'),
                  end_time: Time.zone.parse('1/2/2016 11:30:00'))
                create_policy_balances
                update_balances
              end

              it do
                subject
                expect(JSON.parse(response.body)).to eq(
                  [
                    {
                      'employee' => employee_id,
                      'category' => "vacation",
                      'periods' => [
                          {
                            'type' => "balancer",
                            'start_date' => '2014-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 100,
                            'balance' => 100
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2015-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 100,
                            'balance' => 200
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2016-02-01',
                            'validity_date' => nil,
                            'amount_taken' => 100,
                            'period_result' => 0,
                            'balance' => -140
                          }
                      ]
                    }
                  ]
                )
              end
            end
          end
        end
      end

      context 'when there is a time off that begins in the current period and ends in the next one' do
        context 'and policy does not have end dates' do
          before do
            vacation_balancer_policy_A.update!(end_day: nil, end_month: nil, amount: 12000)
            vacation_policy_A_assignation.update!(effective_at: assignation_date)
            create(:employee_balance_manual,
              effective_at:
                assignation_date + Employee::Balance::ASSIGNATION_OFFSET,
              manual_amount: manual_amount_for_balance, time_off_category: vacation_category,
              resource_amount: 0, employee: employee)
          end

          context 'when there are many active balances' do
            let(:assignation_date) { DateTime.new(2015, 10, 10) }
            let(:manual_amount_for_balance) { 10000 }
            before { Timecop.freeze(2018, 1, 1, 0, 0) }

            context 'when first period amount used' do
              context 'in current period' do
                before do
                  create(:time_off,
                    time_off_category: vacation_category, employee: employee,
                    start_time: Date.new(2017, 12, 26), end_time: Date.new(2018, 1, 8))
                  create_policy_balances
                  update_balances
                end

                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        'employee' => employee_id,
                        'category' => "vacation",
                        'periods' => [
                          {
                            'type' => "balancer",
                            'start_date' => '2015-10-10',
                            'validity_date' => nil,
                            'amount_taken' => 10000,
                            'period_result' => 0,
                            'balance' => 10000
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2016-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 8720,
                            'period_result' =>  3280,
                            'balance' => 22000
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2017-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 12000,
                            'balance' => 25360
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2018-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 12000,
                            'balance' => 27280
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2019-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 12000,
                            'balance' => 39280
                          }
                        ]
                      }
                    ]
                  )
                end
              end

              context 'in previous periods' do
                before do
                  create(:time_off,
                    time_off_category: vacation_category, employee: employee,
                    start_time: Date.new(2015, 11, 1), end_time: Date.new(2015, 11, 11))
                  create(:time_off,
                    time_off_category: vacation_category, employee: employee,
                    start_time: Date.new(2017, 12, 28), end_time: Date.new(2018, 1, 1))
                  create_policy_balances
                  update_balances
                end

                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        'employee' => employee_id,
                        'category' => "vacation",
                        'periods' => [
                          {
                            'type' => "balancer",
                            'start_date' => '2016-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 10160,
                            'period_result' => 1840,
                            'balance' => 7600
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2017-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 12000,
                            'balance' => 13840
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2018-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 12000,
                            'balance' => 25840
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2019-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 12000,
                            'balance' => 37840
                          }
                        ]
                      }
                    ]
                  )
                end
              end
            end

            context 'when there are more than one time off' do
              before do
                create(:time_off,
                  time_off_category: vacation_category, employee: employee,
                  start_time: Date.new(2016, 12, 26), end_time: Date.new(2017, 1, 1))
                create(:time_off,
                  time_off_category: vacation_category, employee: employee,
                  start_time: Date.new(2017, 12, 26), end_time: Date.new(2018, 1, 1))
                create_policy_balances
                update_balances
              end

              it do
                subject
                expect(JSON.parse(response.body)).to eq(
                  [
                    {
                      'employee' => employee_id,
                      'category' => "vacation",
                      'periods' => [
                        {
                          'type' => "balancer",
                          'start_date' => '2016-01-01',
                          'validity_date' => nil,
                          'amount_taken' => 7280,
                          'period_result' =>  4720,
                          'balance' => 13360
                        },
                        {
                          'type' => "balancer",
                          'start_date' => '2017-01-01',
                          'validity_date' => nil,
                          'amount_taken' => 0,
                          'period_result' =>  12000,
                          'balance' => 16720
                        },
                        {
                          'type' => "balancer",
                          'start_date' => '2018-01-01',
                          'validity_date' => nil,
                          'amount_taken' => 0,
                          'period_result' => 12000,
                          'balance' => 28720
                        },
                        {
                          'type' => "balancer",
                          'start_date' => '2019-01-01',
                          'validity_date' => nil,
                          'amount_taken' => 0,
                          'period_result' => 12000,
                          'balance' => 40720
                        }
                      ]
                    }
                  ]
                )
              end
            end
          end

          context 'when there is one or less active balances' do
            let(:assignation_date) { DateTime.new(2016, 10, 10) }
            before do
              Timecop.freeze(2016, 11, 10, 0, 0)
              create(:time_off,
                time_off_category: vacation_category, employee: employee,
                start_time: Date.new(2016, 12, 26), end_time: Date.new(2017, 1, 8))
              create_policy_balances
              update_balances
            end

            after { Timecop.return }

            context 'and policy assignation amount was 0' do
              let(:manual_amount_for_balance) { 0 }
              before { subject }

              it do
                expect(JSON.parse(response.body)).to eq(
                  [
                    {
                      'employee' => employee_id,
                      'category' => "vacation",
                      'periods' => [
                          {
                            'type' => "balancer",
                            'start_date' => '2016-10-10',
                            'validity_date' => nil,
                            'amount_taken' => 0,
                            'period_result' => 0,
                            'balance' => -8640
                          },
                          {
                            'type' => "balancer",
                            'start_date' => '2017-01-01',
                            'validity_date' => nil,
                            'amount_taken' => 12000,
                            'period_result' => 0,
                            'balance' => -6720
                          }
                      ]
                    }
                  ]
                )
              end
            end

            context 'and policy assignation amount was different than 0 ' do
              context 'and smaller than time off amount' do
                let(:manual_amount_for_balance) { 7000 }

                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        'employee' => employee_id,
                        'category' => "vacation",
                        'periods' => [
                            {
                              'type' => "balancer",
                              'start_date' => '2016-10-10',
                              'validity_date' => nil,
                              'amount_taken' => 7000,
                              'period_result' => 0,
                              'balance' => -1640
                            },
                            {
                              'type' => "balancer",
                              'start_date' => '2017-01-01',
                              'validity_date' => nil,
                              'amount_taken' => 11720,
                              'period_result' => 280,
                              'balance' => 280
                            }
                        ]
                      }
                    ]
                  )
                end
              end

              context 'and greater than time off amount' do
                context 'and smaller than whole time off amount' do
                  before { subject }
                  let(:manual_amount_for_balance) { 10000 }

                  it do
                    expect(JSON.parse(response.body)).to eq(
                      [
                        {
                          'employee' => employee_id,
                          'category' => "vacation",
                          'periods' => [
                              {
                                'type' => "balancer",
                                'start_date' => '2016-10-10',
                                'validity_date' => nil,
                                'amount_taken' => 10000,
                                'period_result' => 0,
                                'balance' => 1360
                              },
                              {
                                'type' => "balancer",
                                'start_date' => '2017-01-01',
                                'validity_date' => nil,
                                'amount_taken' => 8720,
                                'period_result' => 3280,
                                'balance' => 3280
                              }
                          ]
                        }
                      ]
                    )
                  end
                end

                context 'and greater than whole time off amount' do
                  before { subject }
                  let(:manual_amount_for_balance) { 20000 }

                  it do
                    expect(JSON.parse(response.body)).to eq(
                      [
                        {
                          'employee' => employee_id,
                          'category' => "vacation",
                          'periods' => [
                              {
                                'type' => "balancer",
                                'start_date' => '2016-10-10',
                                'validity_date' => nil,
                                'amount_taken' => 18720,
                                'period_result' => 1280,
                                'balance' => 11360
                              },
                              {
                                'type' => "balancer",
                                'start_date' => '2017-01-01',
                                'validity_date' => nil,
                                'amount_taken' => 0,
                                'period_result' => 12000,
                                'balance' => 13280
                              }
                          ]
                        }
                      ]
                    )
                  end
                end

                context 'and there are active periods' do
                  let(:manual_amount_for_balance) { 20000 }

                  before do
                    Timecop.freeze(2017, 11, 10, 0, 0)
                  end

                  it do
                    subject
                    expect(JSON.parse(response.body)).to eq(
                      [
                        {
                          'employee' => employee_id,
                          'category' => "vacation",
                          'periods' => [
                              {
                                'type' => "balancer",
                                'start_date' => '2016-10-10',
                                'validity_date' => nil,
                                'amount_taken' => 18720,
                                'period_result' => 1280,
                                'balance' => 11360
                              },
                              {
                                'type' => "balancer",
                                'start_date' => '2017-01-01',
                                'validity_date' => nil,
                                'amount_taken' => 0,
                                'period_result' => 12000,
                                'balance' => 13280
                              },
                              {
                                'type' => "balancer",
                                'start_date' => '2018-01-01',
                                'validity_date' => nil,
                                'amount_taken' => 0,
                                'period_result' => 12000,
                                'balance' => 25280
                              }
                          ]
                        }
                      ]
                    )
                  end

                  context 'and their amount is used in next period' do
                    let(:manual_amount_for_balance) { 20000 }

                    before do
                      create(:time_off,
                        time_off_category: vacation_category, employee: employee,
                        start_time: Date.new(2018, 1, 1), end_time: Date.new(2018, 1, 8))
                      Employee::Balance.all.order(:effective_at).each do |balance|
                        UpdateEmployeeBalance.new(balance).call
                      end
                      subject
                    end

                    it do
                      expect(JSON.parse(response.body)).to eq(
                        [
                          {
                            'employee' => employee_id,
                            'category' => "vacation",
                            'periods' => [
                                {
                                  'type' => "balancer",
                                  'start_date' => '2016-10-10',
                                  'validity_date' => nil,
                                  'amount_taken' => 20000,
                                  'period_result' => 0,
                                  'balance' => 11360
                                },
                                {
                                  'type' => "balancer",
                                  'start_date' => '2017-01-01',
                                  'validity_date' => nil,
                                  'amount_taken' => 8800,
                                  'period_result' => 3200,
                                  'balance' => 13280
                                },
                                {
                                  'type' => "balancer",
                                  'start_date' => '2018-01-01',
                                  'validity_date' => nil,
                                  'amount_taken' => 0,
                                  'period_result' => 12000,
                                  'balance' => 15200
                                }
                            ]
                          }
                        ]
                      )
                    end
                  end
                end
              end
            end
          end
        end

        context 'but the validity date of the current period is after the end of the time off' do
          let(:vacation_policy_A_assignation_date) { Date.new(2016,1,1) }
          before do
            create(:time_off,
              start_time: Time.zone.parse('31/12/2016 23:30:00'),
              end_time: Time.zone.parse('1/1/2017 00:30:00'),
              employee: employee,
              time_off_category: vacation_category
            )

            create_policy_balances
            update_balances
            subject
          end
          it do
             expect(JSON.parse(response.body)).to eq(
               [
                 {
                   'employee' => employee_id,
                   'category' => "vacation",
                   'periods' =>
                     [
                         {
                           'type' => "balancer",
                           'start_date' => '2016-01-01',
                           'validity_date' => '2017-04-01',
                           'amount_taken' => 60,
                           'period_result' => 40,
                           'balance' => 70
                         },
                         {
                           'type' => "balancer",
                           'start_date' => '2017-01-01',
                           'validity_date' => '2018-04-01',
                           'amount_taken' => 0,
                           'period_result' => vacation_balancer_policy_A_amount,
                           'balance' => 100
                         }
                     ]
                 }
               ]
             )
          end
        end
        context 'but the validity date of the current period is in the middle of the time off' do
          let(:vacation_policy_A_assignation_date) { Date.new(2016,1,1) }
          let(:vacation_balancer_policy_A) do
            create(:time_off_policy, time_off_category: vacation_category,
              amount: vacation_balancer_policy_A_amount,
              end_day: 1,
              end_month: 1,
              years_to_effect: 1
            )
          end
          before(:each) do
            create_policy_balances
          end
          context ' and the time off ends in the same day of the validity date' do
            before do
              create(:time_off,
                start_time: Time.zone.parse('1/1/2017 00:30:00'),
                end_time: Time.zone.parse('1/1/2017 1:30:00'),
                employee: employee,
                time_off_category: vacation_category
              )
              update_balances
              subject
            end
            it do
               expect(JSON.parse(response.body)).to eq(
                 [
                   {
                     'employee' => employee_id,
                     'category' => "vacation",
                     'periods' =>
                       [
                           {
                             'type' => "balancer",
                             'start_date' => '2016-01-01',
                             'validity_date' => '2017-01-01',
                             'amount_taken' => 60,
                             'period_result' => 40,
                             'balance' => 100
                           },
                           {
                             'type' => "balancer",
                             'start_date' => '2017-01-01',
                             'validity_date' => '2018-01-01',
                             'amount_taken' => 0,
                             'period_result' => 100,
                             'balance' => 100
                           }
                       ]
                   }
                 ]
               )
            end
          end
          context 'and the time off ends in the same day of the validity date' do
            before do
              create(:time_off,
                start_time: Time.zone.parse('1/1/2017 23:30:00'),
                end_time: Time.zone.parse('2/1/2017 00:30:00'),
                employee: employee,
                time_off_category: vacation_category
              )
              create_policy_balances
              update_balances
              subject
            end
            it do
               expect(JSON.parse(response.body)).to eq(
                 [
                   {
                     'employee' => employee_id,
                     'category' => "vacation",
                     'periods' =>
                       [
                           {
                             'type' => "balancer",
                             'start_date' => '2016-01-01',
                             'validity_date' => '2017-01-01',
                             'amount_taken' => 30,
                             'period_result' => 70,
                             'balance' => 100
                           },
                           {
                             'type' => "balancer",
                             'start_date' => '2017-01-01',
                             'validity_date' => '2018-01-01',
                             'amount_taken' => 30,
                             'period_result' => 70,
                             'balance' => 70
                           }
                       ]
                   }
                 ]
               )
            end
          end
        end
      end
      context 'when there is a time off that begins in the current period after previous period validity date' do
        let(:vacation_policy_A_assignation_date) { Time.now - 2.years }
        before do
          create_policy_balances
          create(:time_off, start_time: Time.zone.parse('2/4/2016 00:00:00'),
            end_time: Time.zone.parse('2/4/2016 02:30:00'), employee: employee,
            time_off_category: vacation_category
          )
          update_balances
        end
        it do
          subject
           expect(JSON.parse(response.body)).to eq(
             [
               {
                 'employee' => employee_id,
                 'category' => "vacation",
                 'periods' =>
                   [
                       {
                         'type' => "balancer",
                         'start_date' => '2015-01-01',
                         'validity_date' => '2016-04-01',
                         'amount_taken' => 0,
                         'period_result' => 100,
                         'balance' => 100
                       },
                       {
                         'type' => "balancer",
                         'start_date' => '2016-01-01',
                         'validity_date' => '2017-04-01',
                         'amount_taken' => 100,
                         'period_result' => 0,
                         'balance' => -50
                       },
                       {
                         'type' => "balancer",
                         'start_date' => '2017-01-01',
                         'validity_date' => '2018-04-01',
                         'amount_taken' => 50,
                         'period_result' => 50,
                         'balance' => 50
                       },
                   ]
               }
             ]
           )
        end
      end
      context 'when there are negative balances from previous periods' do
        before do
          create(:time_off, start_time: Time.zone.parse('1/12/2016 00:00:00'),
            end_time: Time.zone.parse('1/12/2016 02:30:00'), employee: employee,
            time_off_category: vacation_category
          )
          create_policy_balances
          update_balances
        end
         it do
           subject
           expect(JSON.parse(response.body)).to eq(
             [
               {
                 'employee' => employee_id,
                 'category' => "vacation",
                 'periods' =>
                   [
                       {
                         'type' => "balancer",
                         'start_date' => '2016-01-01',
                         'validity_date' => '2017-04-01',
                         'amount_taken' => 100,
                         'period_result' => 0,
                         'balance' => -50
                       },
                       {
                         'type' => "balancer",
                         'start_date' => '2017-01-01',
                         'validity_date' => '2018-04-01',
                         'amount_taken' => 50,
                         'period_result' => vacation_balancer_policy_A_amount - 50,
                         'balance' => vacation_balancer_policy_A_amount - 50
                       }
                   ]
               }
             ]
           )
         end
      end

      context 'when there are many previous period with active amounts at the beginning of the current period' do
        let(:vacation_balancer_policy_A) do
          create(:time_off_policy, :with_end_date, time_off_category: vacation_category,
            amount: vacation_balancer_policy_A_amount, years_to_effect: 2
          )
        end
        let(:vacation_policy_A_assignation_date) { Time.now - 2.years }
        before do
          create(:time_off, start_time: Time.zone.parse('31/12/2015 23:30:00'),
            end_time: Time.zone.parse('1/1/2016 00:30:00'), employee: employee,
            time_off_category: vacation_category)
          create_policy_balances
          update_balances
          subject
        end
        it do
           expect(JSON.parse(response.body)).to eq(
             [
               {
                 'employee' => employee_id,
                 'category' => "vacation",
                 'periods' =>
                   [
                       {
                         'type' => "balancer",
                         'start_date' => '2014-01-01',
                         'validity_date' => '2016-04-01',
                         'amount_taken' => 60,
                         'period_result' => 40,
                         'balance' => 100
                       },
                       {
                         'type' => "balancer",
                         'start_date' => '2015-01-01',
                         'validity_date' => '2017-04-01',
                         'amount_taken' => 0,
                         'period_result' => 100,
                         'balance' => 170
                       },
                       {
                         'type' => "balancer",
                         'start_date' => '2016-01-01',
                         'validity_date' => '2018-04-01',
                         'amount_taken' => 0,
                         'period_result' => 100,
                         'balance' => 200
                       },
                       {
                         'type' => "balancer",
                         'start_date' => '2017-01-01',
                         'validity_date' => '2019-04-01',
                         'amount_taken' => 0,
                         'period_result' => 100,
                         'balance' => 200
                       }
                   ]
               }
             ]
           )
        end
      end
    end
    context 'counter type' do
      let(:emergency_category) do
        create(:time_off_category, account: Account.current, name: 'emergency')
      end
      let(:emergency_counter_policy) do
         create(:time_off_policy, :as_counter, time_off_category: emergency_category)
      end

      let(:emergency_policy_assignation_date) { Time.now }
      let!(:emergency_policy_assignation) do
        create(:employee_time_off_policy,
          employee: employee, effective_at: emergency_policy_assignation_date,
          time_off_policy: emergency_counter_policy
        )
      end
      context 'when a category has current but not next period in the system already' do
        before do
          create_policy_balances
          subject
        end
        it do
          expect(JSON.parse(response.body)).to eq(
            [
              {
                'employee' => employee_id,
                'category' => "emergency",
                'periods' => [
                    {
                      'type' => "counter",
                      'start_date' => '2016-01-01',
                      'validity_date' => nil,
                      'amount_taken' => 0,
                      'period_result' => 0,
                      'balance' => 0
                    },
                    {
                      'type' => "counter",
                      'start_date' => '2017-01-01',
                      'validity_date' => nil,
                      'amount_taken' => 0,
                      'period_result' => 0,
                      'balance' => 0
                    },
                ]
              }
            ]
          )
        end
      end


      context 'when the category has current and next period in the system and a time off' do
        before do
          create_policy_balances
          create(:time_off, start_time: Time.zone.parse('31/12/2016 23:30:00'),
            end_time: Time.zone.parse('1/1/2017 00:30:00'), employee: employee,
            time_off_category: emergency_category
          )
          update_balances
          subject
        end
        it do
          expect(JSON.parse(response.body)).to eq(
            [
              {
                'employee' => employee_id,
                'category' => "emergency",
                'periods' => [
                    {
                      'type' => "counter",
                      'start_date' => '2016-01-01',
                      'validity_date' => nil,
                      'amount_taken' => 30,
                      'period_result' => -30,
                      'balance' => -30
                    },
                    {
                      'type' => "counter",
                      'start_date' => '2017-01-01',
                      'validity_date' => nil,
                      'amount_taken' => 30,
                      'period_result' => -30,
                      'balance' => -30
                    }
                ]
              }
            ]
          )
        end
      end
    end
  end
end

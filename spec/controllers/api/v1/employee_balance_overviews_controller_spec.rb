require 'rails_helper'
require 'fakeredis/rspec'

RSpec.describe API::V1::EmployeeBalanceOverviewsController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let!(:employee) { create(:employee, account: account) }
  let(:vacation_category) {create(:time_off_category, account: Account.current, name: 'vacation') }
  let(:vacation_balancer_policy_A_amount) { 100 }
  let(:vacation_balancer_policy_A) do
    create(:time_off_policy, :with_end_date, time_off_category: vacation_category,
      amount: vacation_balancer_policy_A_amount
    )
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
        before do
          create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          create(:employee_balance_manual, :addition,
            time_off_category: emergency_category,
            resource_amount: 0,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
            validity_date: nil,
            employee_id: employee_id
          )
        end

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
                          'amount_taken' => 100,
                          'period_result' => 0,
                          'balance' => -50
                        }
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

          create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2017, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2018 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
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

      context 'when a category has current but not next period in the system already' do
        before do
          create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
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
                      'start_date' => '2016-01-01',
                      'validity_date' => '2017-04-01',
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

      context 'when there is a time off that begins in the current period and ends in the next one' do
        context 'but the validity date of the current period is after the end of the time off' do
          let(:vacation_policy_A_assignation_date) { Date.new(2016,1,1) }
          before do
            addition = create(:employee_balance_manual, :addition,
              time_off_category: vacation_category,
              resource_amount: vacation_balancer_policy_A_amount,
              effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
              validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
              employee_id: employee_id
            )
            create(:employee_balance_manual, :addition,
              time_off_category: vacation_category,
              resource_amount: vacation_balancer_policy_A_amount,
              effective_at: DateTime.new(2017, 1, 1, 0, 0, 0),
              validity_date: DateTime.new(2018 , 4, 1, 0, 0, 0),
              employee_id: employee_id
            )

            create(:time_off,
              start_time: Time.zone.parse('31/12/2016 23:30:00'),
              end_time: Time.zone.parse('1/1/2017 00:30:00'),
              employee: employee,
              time_off_category: vacation_category
            )

            create(:employee_balance_manual,
              time_off_category: vacation_category,
              resource_amount:
                -(vacation_balancer_policy_A_amount - 60),
              effective_at: DateTime.new(2017, 4, 1, 0, 0, 0),
              validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
              employee_id: employee_id,
              balance_credit_additions: [addition]
            )
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
            addition = create(:employee_balance_manual, :addition,
              time_off_category: vacation_category,
              resource_amount: vacation_balancer_policy_A_amount,
              effective_at: DateTime.new(2016, 1, 1, 1, 0, 0),
              validity_date: DateTime.new(2017 , 1, 1, 1, 0, 0),
              employee_id: employee_id
            )
            create(:employee_balance_manual, :addition,
              time_off_category: vacation_category,
              resource_amount: vacation_balancer_policy_A_amount,
              effective_at: DateTime.new(2017, 1, 1, 0, 0, 0),
              validity_date: DateTime.new(2018 , 1, 1, 0, 0, 0),
              employee_id: employee_id
            )

            create(:employee_balance_manual,
              time_off_category: vacation_category,
              resource_amount: -100,
              effective_at: DateTime.new(2017, 1, 1, 1, 0, 0),
              validity_date: DateTime.new(2017 , 1, 1, 1, 0, 0),
              employee_id: employee_id,
              balance_credit_additions: [addition]
            )
          end
          context ' and the time off ends in the same day of the validity date' do
            before do
              create(:time_off,
                start_time: Time.zone.parse('1/1/2017 00:30:00'),
                end_time: Time.zone.parse('1/1/2017 1:30:00'),
                employee: employee,
                time_off_category: vacation_category
              )
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
          context ' and the time off ends in the same day of the validity date' do
            before do
              create(:time_off,
                start_time: Time.zone.parse('1/1/2017 23:30:00'),
                end_time: Time.zone.parse('2/1/2017 00:30:00'),
                employee: employee,
                time_off_category: vacation_category
              )
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
          addition_2015 = create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2015, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2016 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2016, 1, 1, 1, 0, 0),
            validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: -vacation_balancer_policy_A_amount,
            balance_credit_additions: [addition_2015],
            effective_at: DateTime.new(2016, 4, 1, 0, 0, 0),
            validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          create(:time_off, start_time: Time.zone.parse('2/4/2016 00:00:00'),
            end_time: Time.zone.parse('2/4/2016 02:30:00'), employee: employee,
            time_off_category: vacation_category
          )
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
                       }
                   ]
               }
             ]
           )
        end
      end
      context 'when there are negative balances from previous periods' do
        before do
          create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          create(:time_off, start_time: Time.zone.parse('1/12/2016 00:00:00'),
            end_time: Time.zone.parse('1/12/2016 02:30:00'), employee: employee,
            time_off_category: vacation_category
          )
          create(:employee_balance_manual, :addition,
            time_off_category: vacation_category ,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2017, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2018 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
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
          addition_2014 = create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2014, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2016 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          addition_2015 = create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2015, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          addition_2016 = create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2018 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: -vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2016, 4, 1, 0, 0, 0),
            balance_credit_additions: [addition_2014],
            employee_id: employee_id
          )
          addition_2017 = create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2017, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2019 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          create(:time_off, start_time: Time.zone.parse('31/12/2016 23:30:00'),
            end_time: Time.zone.parse('1/1/2017 00:30:00'), employee: employee,
            time_off_category: vacation_category
          )
          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: -vacation_balancer_policy_A_amount,
            balance_credit_additions: [addition_2015],
            effective_at: DateTime.new(2017, 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: -vacation_balancer_policy_A_amount,
            balance_credit_additions: [addition_2016],
            effective_at: DateTime.new(2018, 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: -vacation_balancer_policy_A_amount,
            balance_credit_additions: [addition_2017],
            effective_at: DateTime.new(2019, 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
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
                 'periods' =>
                   [
                       {
                         'type' => "balancer",
                         'start_date' => '2014-01-01',
                         'validity_date' => '2016-04-01',
                         'amount_taken' => 0,
                         'period_result' => 100,
                         'balance' => 100
                       },
                       {
                         'type' => "balancer",
                         'start_date' => '2015-01-01',
                         'validity_date' => '2017-04-01',
                         'amount_taken' => 60,
                         'period_result' => 40,
                         'balance' => 200
                       },
                       {
                         'type' => "balancer",
                         'start_date' => '2016-01-01',
                         'validity_date' => '2018-04-01',
                         'amount_taken' => 0,
                         'period_result' => 100,
                         'balance' => 170
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
      let(:emergency_category) {create(:time_off_category, account: Account.current, name: 'emergency')}
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
          create(:employee_balance_manual, :addition,
            time_off_category: emergency_category,
            resource_amount: 0,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
            validity_date: nil,
            employee_id: employee_id
          )
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
                'category' => "emergency",
                'periods' => [
                    {
                      'type' => "counter",
                      'start_date' => '2016-01-01',
                      'validity_date' => nil,
                      'amount_taken' => 0,
                      'period_result' => 0,
                      'balance' => 0
                    }
                ]
              }
            ]
          )
        end
      end


      context 'when the category has current and next period in the system and a time off' do
        before do
          create(:employee_balance_manual, :addition,
            time_off_category: emergency_category,
            resource_amount: 0,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
            validity_date: nil,
            employee_id: employee_id
          )
          create(:employee_balance_manual, :addition,
            time_off_category: emergency_category,
            resource_amount: 30,
            effective_at: DateTime.new(2017, 1, 1, 0, 0, 0),
            validity_date: nil,
            employee_id: employee_id
          )
          a = create(:time_off, start_time: Time.zone.parse('31/12/2016 23:30:00'),
            end_time: Time.zone.parse('1/1/2017 00:30:00'), employee: employee,
            time_off_category: emergency_category
          )
          # Employee::Balance.all.order(:effective_at).each do |balance|
          UpdateEmployeeBalance.new(a.employee_balance).call
          # end
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

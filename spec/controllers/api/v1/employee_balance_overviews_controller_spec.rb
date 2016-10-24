require 'rails_helper'
require 'fakeredis/rspec'

RSpec.describe API::V1::EmployeeBalancesController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let!(:employee) { create(:employee, account: account) }

  let(:vacation_category) {create(:time_off_category, account: Account.current, name: 'vacation')}

  let(:vacation_balancer_policy_A_amount) { 100}
  let(:vacation_balancer_policy_A) do
    create(:time_off_policy, :with_end_date, time_off_category: vacation_category,
      amount: vacation_balancer_policy_A_amount
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
    subject { get :show, id: employee_id }

    before { subject }

    context 'when there are many categories' do
      before do
        vacation_policy_A_assignation
      end
      context' and one category policy is  counter type and the other is balancer type' do
        let!(:emergency_category) {create(:time_off_category, account: Account.current, name: 'emergency')}
        let(:emergency_counter_policy_amount) { 100}
        let(:emergency_counter_policy) do
           create(:time_off_policy, :as_counter, time_off_category: emergency_category)
        end

        let(:emergency_policy_assignation_date) { Time.now }
        let!(:emergency_policy_assignation) do
          create(:employee_time_off_policy,
            employee: employee, effective_at: emergency_policy_assignation_date,
            time_off_policy: emergency_category
          )
        end
      end
      before do
        create(:employee_balance_manual,
          time_off_category: vacation_category,
          resource_amount: vacation_balancer_policy_A_amount,
          effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
          validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
          employee_id: employee_id
        )
        create(:employee_balance_manual,
          time_off_category: emergency_category,
          resource_amount: 0,
          effective_at: nil,
          validity_date: nil,
          employee_id: employee_id
        )
      end

      it '' do
        expect(JSON.parse(response.body)).to eq(
          [
            {
              'employee' => employee_id,
              'category' => "vacation",
              'periods' =>
                [
                    {
                      'type' => "balancer",
                      'start_date' => 1/1/2016,
                      'validity_date' => 1/4/2017,
                      'amount_taken' => 0,
                      'period_result' => vacation_balancer_policy_A_amount,
                      'balance' => vacation_balancer_policy_A_amount
                    }
                ]
            },
            {
              'employee' => employee_id,
              'category' => "emergency",
              'periods' =>
                [
                    {
                      'type' => "counter",
                      'start_date' => 1/1/2016,
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
    context 'when there are no categories' do
        let(:vacation_category) { nil }
        let(:emergency_category) { nil }

        it '' do
          expect(JSON.parse(response.body)).to eq([])
        end
    end

    context 'when in the current period there are no assignations but there are in the next period' do
        let(:vacation_policy_A_assignation_date) { Time.now + 1.year }

        context ' and next period balances exist already' do
          before do
            vacation_policy_A_assignation

            create(:employee_balance_manual,
              time_off_category: vacation_category,
              resource_amount: vacation_balancer_policy_A_amount,
              effective_at: DateTime.new(2017, 1, 1, 0, 0, 0),
              validity_date: DateTime.new(2018 , 4, 1, 0, 0, 0),
              employee_id: employee_id
            )
          end

          it '' do
            expect(JSON.parse(response.body)).to eq(
              [
                {
                  'employee' => employee_id,
                  'category' => "vacation",
                  'periods' => [
                      {
                        'type' => "balancer",
                        'start_date' => 1/1/2017,
                        'validity_date' => 1/4/2018,
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
          it '' do
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
      before do
        vacation_policy_A_assignation
      end
      context 'when a category has current but not next period in the system already' do
        it '' do
          expect(JSON.parse(response.body)).to eq(
            [
              {
                'employee' => employee_id,
                'category' => "vacation",
                'periods' => [
                    {
                      'type' => "balancer",
                      'start_date' => 1/1/2016,
                      'validity_date' => 1/4/2017,
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
            removal_2016 = create(:employee_balance_manual,
              time_off_category: vacation_category,
              resource_amount: vacation_balancer_policy_A_amount,
              effective_at: DateTime.new(2017, 4, 1, 0, 0, 0),
              validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
              employee_id: employee_id
            )
            create(:employee_balance_manual,
              time_off_category: vacation_category,
              resource_amount: vacation_balancer_policy_A_amount,
              effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
              validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
              balance_credit_removal_id: removal_2016,
              employee_id: employee_id
            )

            create(:time_off, start_time: Time.zone.parse('31/12/2016 23:30:00'),
              end_time: Time.zone.parse('1/1/2017 00:30:00'),
              employee: employee,
              time_off_category: vacation_category
            )
          end
          it "" do
             expect(JSON.parse(response.body)).to eq(
               [
                 {
                   'employee' => employee_id,
                   'category' => "vacation",
                   'periods' =>
                     [
                         {
                           'type' => "balancer",
                           'start_date' => 1/1/2016,
                           'validity_date' => 1/4/2017,
                           'amount_taken' => 60,
                           'period_result' => 40,
                           'balance' => 40
                         },
                         {
                           'type' => "balancer",
                           'start_date' => 1/1/2017,
                           'validity_date' => 1/4/2018,
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
      end
      context 'when there is a time off that begins in the current period after previous period validity date' do
        let(:vacation_policy_A_assignation_date) { Time.now - 2.years }
        before do
          removal_2016 = create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2016, 4, 1, 0, 0, 0),
            validity_date: DateTime.new(2016 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2015, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2016 , 4, 1, 0, 0, 0),
            balance_credit_removal_id: removal_2016,
            employee_id: employee_id
          )
          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2016, 1, 1, 1, 0, 0),
            validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          create(:time_off, start_time: Time.zone.parse('1/4/2016 00:00:00'),
            end_time: Time.zone.parse('1/4/2017 02:30:00'), employee: employee,
            time_off_category: vacation_category
          )
        end
        it "" do
           expect(JSON.parse(response.body)).to eq(
             [
               {
                 'employee' => employee_id,
                 'category' => "vacation",
                 'periods' =>
                   [
                       {
                         'type' => "balancer",
                         'start_date' => 1/1/2016,
                         'validity_date' => 1/4/2017,
                         'amount_taken' => 0,
                         'period_result' => 100,
                         'balance' => 100
                       },
                       {
                         'type' => "balancer",
                         'start_date' => 1/1/2017,
                         'validity_date' => 1/4/2018,
                         'amount_taken' => -100,
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
          create(:employee_balance_manual,
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
          create(:employee_balance_manual,
            time_off_category: vacation_category ,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2017, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2018 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
        end
         it "" do
           expect(JSON.parse(response.body)).to eq(
             [
               {
                 'employee' => employee_id,
                 'category' => "vacation",
                 'periods' =>
                   [
                       {
                         'type' => "balancer",
                         'start_date' => 1/1/2016,
                         'validity_date' => 1/4/2017,
                         'amount_taken' => 100,
                         'period_result' => 0,
                         'balance' => -50
                       },
                       {
                         'type' => "balancer",
                         'start_date' => 1/1/2017,
                         'validity_date' => 1/4/2018,
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
          removal_2014 = create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: -vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2016, 4, 1, 0, 0, 0),
            validity_date: DateTime.new(2016 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )
          removal_2015 = create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: -vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2017, 4, 1, 0, 0, 0),
            validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )

          removal_2015 = create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: -vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2018, 4, 1, 0, 0, 0),
            validity_date: DateTime.new(2018 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )

          removal_2016 = create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: -vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2020, 4, 1, 0, 0, 0),
            validity_date: DateTime.new(2020 , 4, 1, 0, 0, 0),
            employee_id: employee_id
          )

          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2014, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2016 , 4, 1, 0, 0, 0),
            balance_credit_removal_id: removal_2014,
            employee_id: employee_id
          )
          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2015, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2017 , 4, 1, 0, 0, 0),
            balance_credit_removal_id: removal_2015,
            employee_id: employee_id
          )
          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2018 , 4, 1, 0, 0, 0),
            balance_credit_removal_id: removal_2016,
            employee_id: employee_id
          )
          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_A_amount,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
            validity_date: DateTime.new(2019 , 4, 1, 0, 0, 0),
            balance_credit_removal_id: removal_2017,
            employee_id: employee_id
          )
          create(:time_off, start_time: Time.zone.parse('31/12/2016 23:30:00'),
            end_time: Time.zone.parse('1/1/2017 00:30:00'), employee: employee,
            time_off_category: vacation_category
          )
        end
        it "" do
           expect(JSON.parse(response.body)).to eq(
             [
               {
                 'employee' => employee_id,
                 'category' => "vacation",
                 'periods' =>
                   [
                       {
                         'type' => "balancer",
                         'start_date' => 1/1/2014,
                         'validity_date' => 1/4/2017,
                         'amount_taken' => 100,
                         'period_result' => 0,
                         'balance' => 100
                       },
                       {
                         'type' => "balancer",
                         'start_date' => 1/1/2015,
                         'validity_date' => 1/4/2018,
                         'amount_taken' => 0,
                         'period_result' => 100,
                         'balance' => 200
                       },
                       {
                         'type' => "balancer",
                         'start_date' => 1/1/2016,
                         'validity_date' => 1/4/2019,
                         'amount_taken' => 0,
                         'period_result' => 100,
                         'balance' => 200
                       },
                       {
                         'type' => "balancer",
                         'start_date' => 1/1/2017,
                         'validity_date' => 1/4/2020,
                         'amount_taken' => 0,
                         'period_result' => 100,
                         'balance' => 250
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
      let(:emergency_counter_policy_amount) { 100}
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

        it '' do
          expect(JSON.parse(response.body)).to eq(
            [
              {
                'employee' => employee_id,
                'category' => "vacation",
                'periods' => [
                    {
                      'type' => "balancer",
                      'start_date' => 1/1/2016,
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

          create(:employee_balance_manual,
            time_off_category: emergency_category,
            resource_amount: 0,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0),
            validity_date: nil,
            balance_credit_removal_id: removal_2015,
            employee_id: employee_id
          )
          create(:employee_balance_manual,
            time_off_category: emergency_category,
            resource_amount: -150,
            effective_at: DateTime.new(2017, 1, 1, 0, 0, 0),
            validity_date: nil,
            employee_id: employee_id
          )
          create(:time_off, start_time: Time.zone.parse('31/12/2016 23:30:00'),
            end_time: Time.zone.parse('1/1/2017 00:30:00'), employee: employee,
            time_off_category: vacation_category
          )
        end
        it '' do
          expect(JSON.parse(response.body)).to eq(
            [
              {
                'employee' => employee_id,
                'category' => "emergency",
                'periods' => [
                    {
                      'type' => "counter",
                      'start_date' => 1/1/2016,
                      'validity_date' => nil,
                      'amount_taken' => 150,
                      'period_result' => -150,
                      'balance' => -150
                    }
                ]
              },
              {
                'employee' => employee_id,
                'category' => "emergency",
                'periods' => [
                    {
                      'type' => "counter",
                      'start_date' => 1/1/2016,
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
    end

  end
end

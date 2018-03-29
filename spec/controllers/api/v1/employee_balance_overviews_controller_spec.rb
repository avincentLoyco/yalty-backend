require "rails_helper"

RSpec.describe API::V1::EmployeeBalanceOverviewsController, type: :controller do
  include_context "shared_context_headers"
  include_context "shared_context_timecop_helper"

  let!(:vacation_category) { create(:time_off_category, account: Account.current, name: "vacation") }
  let(:vacation_balancer_policy_A_amount) { 100 }
  let(:vacation_balancer_policy_A) do
    create(:time_off_policy, :with_end_date, time_off_category: vacation_category,
      amount: vacation_balancer_policy_A_amount
    )
  end

  let(:presence_policy) { create(:presence_policy, account: account, occupation_rate: 1.0,
    standard_day_duration: 1440, default_full_time: true) }

  before do
    account.presence_policies.find_by(standard_day_duration: 9600).destroy!
  end

  let(:presence_days)  do
    [1,2,3,4,5,6,7].map do |i|
      create(:presence_day, order: i, presence_policy: presence_policy)
    end
  end

  let!(:occupation_rate_definition) do
    create(:employee_attribute_definition,
      name: "occupation_rate",
      account: Account.current,
      attribute_type: Attribute::Number.attribute_type,
      validation: { range: [0, 1] })
  end

  let!(:firstname_definition) do
    create(:employee_attribute_definition,
      account: Account.current,
      name: "firstname",
      attribute_type: Attribute::String.attribute_type,
      validation: { presence: true })
  end

  let!(:lastname_definition) do
    create(:employee_attribute_definition,
      account: Account.current,
      name: "lastname",
      attribute_type: Attribute::String.attribute_type,
      validation: { presence: true })
  end

  let(:effective_at) { Date.new(2016, 1, 1) }

  let(:event_params) do
    {
      effective_at: effective_at,
      event_type: "hired",
      time_off_policy_amount: 10,
      employee: {},
      presence_policy_id: presence_policy.id,
      employee_attributes: employee_attributes_params
    }
  end
  let(:employee_attributes_params) do
    [
      {
        value: 1.0,
        attribute_name: "occupation_rate",
      },
      {
        value: "John",
        attribute_name: "firstname"
      },
      {
        value: "Smith",
        attribute_name: "lastname"
      }
    ]
  end
  let(:contract_end_params) do
    {
      effective_at: effective_at + 6.months,
      event_type: "contract_end",
      employee: {
        id: event.employee_id
      }
    }
  end

  subject(:create_hired_event) do
    Events::WorkContract::Create.call(event_params)
  end

  subject(:create_contract_end) do
    Events::ContractEnd::Create.call(contract_end_params)
  end

  subject(:create_policy_balances) do
    ManageEmployeeBalanceAdditions.new(emergency_policy_assignation).call
  end

  subject(:update_balances) do
    Employee::Balance.order(:effective_at).map { |balance| UpdateEmployeeBalance.new(balance).call }
  end

  before do
    presence_days.map do |presence_day|
      create(:time_entry, presence_day: presence_day, start_time: "00:00", end_time: "24:00")
    end
  end

  # let!(:epp) do
  #   create(:employee_presence_policy,
  #     presence_policy: presence_policy,
  #     employee: employee,
  #     effective_at: Date.today - 3.years
  #   )
  # end
  # let(:vacation_policy_A_assignation_date) { Time.now }
  # let(:vacation_policy_A_assignation) do
  #   create(:employee_time_off_policy,
  #     employee: employee, effective_at: vacation_policy_A_assignation_date,
  #     time_off_policy: vacation_balancer_policy_A
  #   )
  # end


  describe "GET #show" do
    let(:event) { create_hired_event }
    subject { get :show, employee_id: event.employee.id }

    context "when there are many categories" do
      context" and one category policy is  counter type and the other is balancer type" do
        let!(:emergency_category) do
          create(:time_off_category, account: Account.current, name: "emergency")
        end
        let(:emergency_counter_policy) do
           create(:time_off_policy, :as_counter, time_off_category: emergency_category)
        end
        let(:emergency_policy_assignation_date) { event.effective_at }
        let!(:emergency_policy_assignation) do
          create(:employee_time_off_policy,
            employee: event.employee, effective_at: emergency_policy_assignation_date,
            time_off_policy: emergency_counter_policy
          )
        end
        before { create_policy_balances }

        it do
          subject
          expect(JSON.parse(response.body)).to eq(
            [
              {
                "employee" => event.employee_id,
                "category" => "emergency",
                "periods" =>
                  [
                      {
                        "type" => "counter",
                        "start_date" => "2016-01-01",
                        "validity_date" => nil,
                        "amount_taken" => 0,
                        "period_result" => 0,
                        "balance" => 0
                      },
                      {
                        "type" => "counter",
                        "start_date" => "2017-01-01",
                        "validity_date" => nil,
                        "amount_taken" => 0,
                        "period_result" => 0,
                        "balance" => 0
                      }
                  ]
              },
              {
                "employee" => event.employee_id,
                "category" => "vacation",
                "periods" =>
                  [
                      {
                        "type" => "balancer",
                        "start_date" => "2016-01-01",
                        "validity_date" => nil,
                        "amount_taken" => 0,
                        "period_result" => 14400,
                        "balance" => 14400
                      },
                      {
                        "type" => "balancer",
                        "start_date" => "2017-01-01",
                        "validity_date" => nil,
                        "amount_taken" => 0,
                        "period_result" => 14400,
                        "balance" => 28800
                      }
                  ]
              }
            ]
          )
        end

        context "and both have time offs " do
          before do
            # vacation_policy_A_assignation
            create(:time_off, start_time: Time.zone.parse("1/2/2016 00:00:00"),
              end_time: Time.zone.parse("1/2/2016 02:30:00"), employee: event.employee,
              time_off_category: vacation_category
            )
            create(:time_off, start_time: Time.zone.parse("1/2/2016 05:00:00"),
              end_time: Time.zone.parse("1/2/2016 07:30:00"), employee: event.employee,
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
                  "employee" => event.employee_id,
                  "category" => "emergency",
                  "periods" =>
                    [
                        {
                          "type" => "counter",
                          "start_date" => "2016-01-01",
                          "validity_date" => nil,
                          "amount_taken" => 150,
                          "period_result" => -150,
                          "balance" => -150
                        },
                        {
                          "type" => "counter",
                          "start_date" => "2017-01-01",
                          "validity_date" => nil,
                          "amount_taken" => 0,
                          "period_result" => 0,
                          "balance" => 0
                        },
                    ]
                },
                {
                  "employee" => event.employee_id,
                  "category" => "vacation",
                  "periods" =>
                    [
                        {
                          "type" => "balancer",
                          "start_date" => "2016-01-01",
                          "validity_date" => nil,
                          "amount_taken" => 150,
                          "period_result" => 14250,
                          "balance" => 14250
                        },
                        {
                          "type" => "balancer",
                          "start_date" => "2017-01-01",
                          "validity_date" => nil,
                          "amount_taken" => 0,
                          "period_result" => 14400,
                          "balance" => 28650
                        },
                    ]
                }
              ]
            )
          end

        end
      end
    end

    context "when in the current period there are no assignations but there are in the next period" do
      let(:effective_at) { Date.new(2018, 1, 1) }

      context " and hired event is in the next period" do
        it do
          subject
          expect(JSON.parse(response.body)).to eq(
            [
              {
                "employee" => event.employee_id,
                "category" => "vacation",
                "periods" => [
                    {
                      "type" => "balancer",
                      "start_date" => "2018-01-01",
                      "validity_date" => nil,
                      "amount_taken" => 0,
                      "period_result" => 14400,
                      "balance" => 14400
                    }
                ]
              }
            ]
          )
        end
      end
    end

    context "balancer type" do
      context "when there is contract end" do
        before do
          create_contract_end
        end

        context "and balances do not have validity date" do

          context "contract end in next period" do
            context "and there are time offs" do
              before do
                create(:time_off,
                  employee: event.employee, time_off_category: vacation_category,
                  start_time: Time.zone.parse("1/2/2016 07:30:00"), end_time: end_time)
                update_balances
              end

              context "and whole amount used" do
                context "only from active" do
                  let(:end_time) { Time.zone.parse("1/2/2016 11:30:00") }

                  it do
                    subject
                    expect(JSON.parse(response.body)).to eq(
                      [
                        {
                          "employee" => event.employee_id,
                          "category" => "vacation",
                          "periods" => [
                              {
                                "type" => "balancer",
                                "start_date" => "2016-01-01",
                                "validity_date" => nil,
                                "amount_taken" => 240,
                                "period_result" => 14160,
                                "balance" => 14160
                              }
                          ]
                        }
                      ]
                    )
                  end
                end

                context "from current and active" do
                  let(:end_time) { Time.zone.parse("1/2/2016 8:30:00") }

                  it do
                    subject
                    expect(JSON.parse(response.body)).to eq(
                      [
                        {
                          "employee" => event.employee_id,
                          "category" => "vacation",
                          "periods" => [
                            {
                              "type" => "balancer",
                              "start_date" => "2016-01-01",
                              "validity_date" => nil,
                              "amount_taken" => 60,
                              "period_result" => 14340,
                              "balance" => 14340
                            }
                          ]
                        }
                      ]
                    )
                  end
                end
              end

              context "and not whole active period amount used" do
                let(:end_time) { Time.zone.parse("1/2/2016 10:30:00") }

                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        "employee" => event.employee_id,
                        "category" => "vacation",
                        "periods" => [
                            {
                              "type" => "balancer",
                              "start_date" => "2016-01-01",
                              "validity_date" => nil,
                              "amount_taken" => 180,
                              "period_result" => 14220,
                              "balance" => 14220
                            }
                        ]
                      }
                    ]
                  )
                end
              end
            end

            context "and there are no time offs" do
              before do
                update_balances
              end

              it do
                subject
                expect(JSON.parse(response.body)).to eq(
                  [
                    {
                      "employee" => event.employee_id,
                      "category" => "vacation",
                      "periods" => [
                        {
                          "type" => "balancer",
                          "start_date" => "2016-01-01",
                          "validity_date" => nil,
                          "amount_taken" => 0,
                          "period_result" => 14400,
                          "balance" => 14400
                        }
                      ]
                    }
                  ]
                )
              end
            end
          end

          context "contract end in current period" do
            context "and no time offs" do
              let(:effective_at) { Date.new(2014, 1, 1) }

              it do
                subject
                expect(JSON.parse(response.body)).to eq(
                  [
                    {
                      "employee" => event.employee_id,
                      "category" => "vacation",
                      "periods" => [
                          {
                            "type" => "balancer",
                            "start_date" => "2014-01-01",
                            "validity_date" => nil,
                            "amount_taken" => 0,
                            "period_result" => 14400,
                            "balance" => 14400
                          }
                      ]
                    }
                  ]
                )
              end
            end

            context "and there is time offs in previous periods" do
              before do
                create(:time_off,
                  employee: event.employee, time_off_category: vacation_category,
                  start_time: Time.zone.parse("1/1/2016 07:30:00"), end_time: end_time)
              end

              context "and not whole period amount used" do
                let(:end_time) { Time.zone.parse("1/1/2016 8:30:00") }

                before do
                  update_balances
                end
                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        "employee" => event.employee_id,
                        "category" => "vacation",
                        "periods" => [
                            {
                              "type" => "balancer",
                              "start_date" => "2016-01-01",
                              "validity_date" => nil,
                              "amount_taken" => 60,
                              "period_result" => 14340,
                              "balance" => 14340
                            }
                        ]
                      }
                    ]
                  )
                end
              end

              context "and whole period amount used" do
                let(:end_time) { effective_at + 12.days }

                before do
                  update_balances
                end

                it do
                  subject
                  expect(JSON.parse(response.body)).to eq(
                    [
                      {
                        "employee" => event.employee_id,
                        "category" => "vacation",
                        "periods" => [
                            {
                              "type" => "balancer",
                              "start_date" => "2016-01-01",
                              "validity_date" => nil,
                              "amount_taken" => 14400,
                              "period_result" => 0,
                              "balance" => -2430
                            }
                        ]
                      }
                    ]
                  )
                end
              end

              #TODO: Uncomment and fix specs
              # context 'and all active periods amount used' do
              #   let(:end_time) { Time.zone.parse('1/1/2015 11:30:00') }

              #   before do
              #     create_policy_balances
              #     update_balances
              #   end

              #   it do
              #     subject
              #     expect(JSON.parse(response.body)).to eq(
              #       [
              #         {
              #           'employee' => employee_id,
              #           'category' => "vacation",
              #           'periods' => [
              #               {
              #                 'type' => "balancer",
              #                 'start_date' => '2016-02-01',
              #                 'validity_date' => nil,
              #                 'amount_taken' => 0,
              #                 'period_result' => 100,
              #                 'balance' => 100
              #               }
              #           ]
              #         }
              #       ]
              #     )
              #   end
              # end
            end

            #TODO: Uncomment and fix specs
            # context 'and there is time off in active period' do
            #   before do
            #     create(:employee_presence_policy,
            #       presence_policy: presence_policy, employee: employee, effective_at: '1/2.2016')
            #     create(:time_off,
            #       employee: employee, time_off_category: vacation_category,
            #       start_time: Time.zone.parse('1/2/2016 07:30:00'),
            #       end_time: Time.zone.parse('1/2/2016 11:30:00'))
            #     create_policy_balances
            #     update_balances
            #   end

            #   it do
            #     subject
            #     expect(JSON.parse(response.body)).to eq(
            #       [
            #         {
            #           'employee' => employee_id,
            #           'category' => "vacation",
            #           'periods' => [
            #               {
            #                 'type' => "balancer",
            #                 'start_date' => '2014-01-01',
            #                 'validity_date' => nil,
            #                 'amount_taken' => 0,
            #                 'period_result' => 100,
            #                 'balance' => 100
            #               },
            #               {
            #                 'type' => "balancer",
            #                 'start_date' => '2015-01-01',
            #                 'validity_date' => nil,
            #                 'amount_taken' => 0,
            #                 'period_result' => 100,
            #                 'balance' => 200
            #               },
            #               {
            #                 'type' => "balancer",
            #                 'start_date' => '2016-02-01',
            #                 'validity_date' => nil,
            #                 'amount_taken' => 100,
            #                 'period_result' => 0,
            #                 'balance' => -140
            #               }
            #           ]
            #         }
            #       ]
            #     )
            #   end
            # end
          end
        end
      end

      #TODO: Uncomment and fix specs
      # context 'when there is a time off that begins in the current period and ends in the next one' do
      #   context 'and policy does not have end dates' do
      #     before do
      #       vacation_balancer_policy_A.update!(end_day: nil, end_month: nil, amount: 12000)
      #       vacation_policy_A_assignation.update!(effective_at: assignation_date)
      #       create(:employee_balance_manual,
      #         effective_at:
      #           assignation_date + Employee::Balance::ASSIGNATION_OFFSET,
      #         manual_amount: manual_amount_for_balance, time_off_category: vacation_category,
      #         resource_amount: 0, employee: employee)
      #     end

      #     context 'when there are many active balances' do
      #       let(:assignation_date) { DateTime.new(2015, 10, 10) }
      #       let(:manual_amount_for_balance) { 10000 }
      #       before { Timecop.freeze(2018, 1, 1, 0, 0) }

      #       context 'when first period amount used' do
      #         context 'in current period' do
      #           before do
      #             create(:time_off,
      #               time_off_category: vacation_category, employee: employee,
      #               start_time: Date.new(2017, 12, 26), end_time: Date.new(2018, 1, 8))
      #             create_policy_balances
      #             update_balances
      #           end

      #           it do
      #             subject
      #             expect(JSON.parse(response.body)).to eq(
      #               [
      #                 {
      #                   'employee' => employee_id,
      #                   'category' => "vacation",
      #                   'periods' => [
      #                     {
      #                       'type' => "balancer",
      #                       'start_date' => '2015-10-10',
      #                       'validity_date' => nil,
      #                       'amount_taken' => 10000,
      #                       'period_result' => 0,
      #                       'balance' => 10000
      #                     },
      #                     {
      #                       'type' => "balancer",
      #                       'start_date' => '2016-01-01',
      #                       'validity_date' => nil,
      #                       'amount_taken' => 8720,
      #                       'period_result' =>  3280,
      #                       'balance' => 22000
      #                     },
      #                     {
      #                       'type' => "balancer",
      #                       'start_date' => '2017-01-01',
      #                       'validity_date' => nil,
      #                       'amount_taken' => 0,
      #                       'period_result' => 12000,
      #                       'balance' => 25360
      #                     },
      #                     {
      #                       'type' => "balancer",
      #                       'start_date' => '2018-01-01',
      #                       'validity_date' => nil,
      #                       'amount_taken' => 0,
      #                       'period_result' => 12000,
      #                       'balance' => 27280
      #                     },
      #                     {
      #                       'type' => "balancer",
      #                       'start_date' => '2019-01-01',
      #                       'validity_date' => nil,
      #                       'amount_taken' => 0,
      #                       'period_result' => 12000,
      #                       'balance' => 39280
      #                     }
      #                   ]
      #                 }
      #               ]
      #             )
      #           end
      #         end

      #         context 'in previous periods' do
      #           before do
      #             create(:time_off,
      #               time_off_category: vacation_category, employee: employee,
      #               start_time: Date.new(2015, 11, 1), end_time: Date.new(2015, 11, 11))
      #             create(:time_off,
      #               time_off_category: vacation_category, employee: employee,
      #               start_time: Date.new(2017, 12, 28), end_time: Date.new(2018, 1, 1))
      #             create_policy_balances
      #             update_balances
      #           end

      #           it do
      #             subject
      #             expect(JSON.parse(response.body)).to eq(
      #               [
      #                 {
      #                   'employee' => employee_id,
      #                   'category' => "vacation",
      #                   'periods' => [
      #                     {
      #                       'type' => "balancer",
      #                       'start_date' => '2016-01-01',
      #                       'validity_date' => nil,
      #                       'amount_taken' => 10160,
      #                       'period_result' => 1840,
      #                       'balance' => 7600
      #                     },
      #                     {
      #                       'type' => "balancer",
      #                       'start_date' => '2017-01-01',
      #                       'validity_date' => nil,
      #                       'amount_taken' => 0,
      #                       'period_result' => 12000,
      #                       'balance' => 13840
      #                     },
      #                     {
      #                       'type' => "balancer",
      #                       'start_date' => '2018-01-01',
      #                       'validity_date' => nil,
      #                       'amount_taken' => 0,
      #                       'period_result' => 12000,
      #                       'balance' => 25840
      #                     },
      #                     {
      #                       'type' => "balancer",
      #                       'start_date' => '2019-01-01',
      #                       'validity_date' => nil,
      #                       'amount_taken' => 0,
      #                       'period_result' => 12000,
      #                       'balance' => 37840
      #                     }
      #                   ]
      #                 }
      #               ]
      #             )
      #           end
      #         end
      #       end

      #       context 'when there are more than one time off' do
      #         before do
      #           create(:time_off,
      #             time_off_category: vacation_category, employee: employee,
      #             start_time: Date.new(2016, 12, 26), end_time: Date.new(2017, 1, 1))
      #           create(:time_off,
      #             time_off_category: vacation_category, employee: employee,
      #             start_time: Date.new(2017, 12, 26), end_time: Date.new(2018, 1, 1))
      #           create_policy_balances
      #           update_balances
      #         end

      #         it do
      #           subject
      #           expect(JSON.parse(response.body)).to eq(
      #             [
      #               {
      #                 'employee' => employee_id,
      #                 'category' => "vacation",
      #                 'periods' => [
      #                   {
      #                     'type' => "balancer",
      #                     'start_date' => '2016-01-01',
      #                     'validity_date' => nil,
      #                     'amount_taken' => 7280,
      #                     'period_result' =>  4720,
      #                     'balance' => 13360
      #                   },
      #                   {
      #                     'type' => "balancer",
      #                     'start_date' => '2017-01-01',
      #                     'validity_date' => nil,
      #                     'amount_taken' => 0,
      #                     'period_result' =>  12000,
      #                     'balance' => 16720
      #                   },
      #                   {
      #                     'type' => "balancer",
      #                     'start_date' => '2018-01-01',
      #                     'validity_date' => nil,
      #                     'amount_taken' => 0,
      #                     'period_result' => 12000,
      #                     'balance' => 28720
      #                   },
      #                   {
      #                     'type' => "balancer",
      #                     'start_date' => '2019-01-01',
      #                     'validity_date' => nil,
      #                     'amount_taken' => 0,
      #                     'period_result' => 12000,
      #                     'balance' => 40720
      #                   }
      #                 ]
      #               }
      #             ]
      #           )
      #         end
      #       end
      #     end

      #     context 'when there is one or less active balances' do
      #       let(:assignation_date) { DateTime.new(2016, 10, 10) }
      #       before do
      #         Timecop.freeze(2016, 11, 10, 0, 0)
      #         create(:time_off,
      #           time_off_category: vacation_category, employee: employee,
      #           start_time: Date.new(2016, 12, 26), end_time: Date.new(2017, 1, 8))
      #         create_policy_balances
      #         update_balances
      #       end

      #       after { Timecop.return }

      #       context 'and policy assignation amount was 0' do
      #         let(:manual_amount_for_balance) { 0 }
      #         before { subject }

      #         it do
      #           expect(JSON.parse(response.body)).to eq(
      #             [
      #               {
      #                 'employee' => employee_id,
      #                 'category' => "vacation",
      #                 'periods' => [
      #                     {
      #                       'type' => "balancer",
      #                       'start_date' => '2016-10-10',
      #                       'validity_date' => nil,
      #                       'amount_taken' => 0,
      #                       'period_result' => 0,
      #                       'balance' => -8640
      #                     },
      #                     {
      #                       'type' => "balancer",
      #                       'start_date' => '2017-01-01',
      #                       'validity_date' => nil,
      #                       'amount_taken' => 12000,
      #                       'period_result' => 0,
      #                       'balance' => -6720
      #                     }
      #                 ]
      #               }
      #             ]
      #           )
      #         end
      #       end

      #       context 'and policy assignation amount was different than 0 ' do
      #         context 'and smaller than time off amount' do
      #           let(:manual_amount_for_balance) { 7000 }

      #           it do
      #             subject
      #             expect(JSON.parse(response.body)).to eq(
      #               [
      #                 {
      #                   'employee' => employee_id,
      #                   'category' => "vacation",
      #                   'periods' => [
      #                       {
      #                         'type' => "balancer",
      #                         'start_date' => '2016-10-10',
      #                         'validity_date' => nil,
      #                         'amount_taken' => 7000,
      #                         'period_result' => 0,
      #                         'balance' => -1640
      #                       },
      #                       {
      #                         'type' => "balancer",
      #                         'start_date' => '2017-01-01',
      #                         'validity_date' => nil,
      #                         'amount_taken' => 11720,
      #                         'period_result' => 280,
      #                         'balance' => 280
      #                       }
      #                   ]
      #                 }
      #               ]
      #             )
      #           end
      #         end

      #         context 'and greater than time off amount' do
      #           context 'and smaller than whole time off amount' do
      #             before { subject }
      #             let(:manual_amount_for_balance) { 10000 }

      #             it do
      #               expect(JSON.parse(response.body)).to eq(
      #                 [
      #                   {
      #                     'employee' => employee_id,
      #                     'category' => "vacation",
      #                     'periods' => [
      #                         {
      #                           'type' => "balancer",
      #                           'start_date' => '2016-10-10',
      #                           'validity_date' => nil,
      #                           'amount_taken' => 10000,
      #                           'period_result' => 0,
      #                           'balance' => 1360
      #                         },
      #                         {
      #                           'type' => "balancer",
      #                           'start_date' => '2017-01-01',
      #                           'validity_date' => nil,
      #                           'amount_taken' => 8720,
      #                           'period_result' => 3280,
      #                           'balance' => 3280
      #                         }
      #                     ]
      #                   }
      #                 ]
      #               )
      #             end
      #           end

      #           context 'and greater than whole time off amount' do
      #             before { subject }
      #             let(:manual_amount_for_balance) { 20000 }

      #             it do
      #               expect(JSON.parse(response.body)).to eq(
      #                 [
      #                   {
      #                     'employee' => employee_id,
      #                     'category' => "vacation",
      #                     'periods' => [
      #                         {
      #                           'type' => "balancer",
      #                           'start_date' => '2016-10-10',
      #                           'validity_date' => nil,
      #                           'amount_taken' => 18720,
      #                           'period_result' => 1280,
      #                           'balance' => 11360
      #                         },
      #                         {
      #                           'type' => "balancer",
      #                           'start_date' => '2017-01-01',
      #                           'validity_date' => nil,
      #                           'amount_taken' => 0,
      #                           'period_result' => 12000,
      #                           'balance' => 13280
      #                         }
      #                     ]
      #                   }
      #                 ]
      #               )
      #             end
      #           end

      #           context 'and there are active periods' do
      #             let(:manual_amount_for_balance) { 20000 }

      #             before do
      #               Timecop.freeze(2017, 11, 10, 0, 0)
      #             end

      #             it do
      #               subject
      #               expect(JSON.parse(response.body)).to eq(
      #                 [
      #                   {
      #                     'employee' => employee_id,
      #                     'category' => "vacation",
      #                     'periods' => [
      #                         {
      #                           'type' => "balancer",
      #                           'start_date' => '2016-10-10',
      #                           'validity_date' => nil,
      #                           'amount_taken' => 18720,
      #                           'period_result' => 1280,
      #                           'balance' => 11360
      #                         },
      #                         {
      #                           'type' => "balancer",
      #                           'start_date' => '2017-01-01',
      #                           'validity_date' => nil,
      #                           'amount_taken' => 0,
      #                           'period_result' => 12000,
      #                           'balance' => 13280
      #                         },
      #                         {
      #                           'type' => "balancer",
      #                           'start_date' => '2018-01-01',
      #                           'validity_date' => nil,
      #                           'amount_taken' => 0,
      #                           'period_result' => 12000,
      #                           'balance' => 25280
      #                         }
      #                     ]
      #                   }
      #                 ]
      #               )
      #             end

      #             context 'and their amount is used in next period' do
      #               let(:manual_amount_for_balance) { 20000 }

      #               before do
      #                 create(:time_off,
      #                   time_off_category: vacation_category, employee: employee,
      #                   start_time: Date.new(2018, 1, 1), end_time: Date.new(2018, 1, 8))
      #                 Employee::Balance.all.order(:effective_at).each do |balance|
      #                   UpdateEmployeeBalance.new(balance).call
      #                 end
      #                 subject
      #               end

      #               it do
      #                 expect(JSON.parse(response.body)).to eq(
      #                   [
      #                     {
      #                       'employee' => employee_id,
      #                       'category' => "vacation",
      #                       'periods' => [
      #                           {
      #                             'type' => "balancer",
      #                             'start_date' => '2016-10-10',
      #                             'validity_date' => nil,
      #                             'amount_taken' => 20000,
      #                             'period_result' => 0,
      #                             'balance' => 11360
      #                           },
      #                           {
      #                             'type' => "balancer",
      #                             'start_date' => '2017-01-01',
      #                             'validity_date' => nil,
      #                             'amount_taken' => 8800,
      #                             'period_result' => 3200,
      #                             'balance' => 13280
      #                           },
      #                           {
      #                             'type' => "balancer",
      #                             'start_date' => '2018-01-01',
      #                             'validity_date' => nil,
      #                             'amount_taken' => 0,
      #                             'period_result' => 12000,
      #                             'balance' => 15200
      #                           }
      #                       ]
      #                     }
      #                   ]
      #                 )
      #               end
      #             end
      #           end
      #         end
      #       end
      #     end
      #   end

      #   context 'but the validity date of the current period is after the end of the time off' do
      #     let(:vacation_policy_A_assignation_date) { Date.new(2016,1,1) }
      #     before do
      #       create(:time_off,
      #         start_time: Time.zone.parse('31/12/2016 23:30:00'),
      #         end_time: Time.zone.parse('1/1/2017 00:30:00'),
      #         employee: employee,
      #         time_off_category: vacation_category
      #       )

      #       create_policy_balances
      #       update_balances
      #       subject
      #     end
      #     it do
      #        expect(JSON.parse(response.body)).to eq(
      #          [
      #            {
      #              'employee' => employee_id,
      #              'category' => "vacation",
      #              'periods' =>
      #                [
      #                    {
      #                      'type' => "balancer",
      #                      'start_date' => '2016-01-01',
      #                      'validity_date' => '2017-04-01',
      #                      'amount_taken' => 60,
      #                      'period_result' => 40,
      #                      'balance' => 70
      #                    },
      #                    {
      #                      'type' => "balancer",
      #                      'start_date' => '2017-01-01',
      #                      'validity_date' => '2018-04-01',
      #                      'amount_taken' => 0,
      #                      'period_result' => vacation_balancer_policy_A_amount,
      #                      'balance' => 100
      #                    }
      #                ]
      #            }
      #          ]
      #        )
      #     end
      #   end
      #   context 'but the validity date of the current period is in the middle of the time off' do
      #     let(:vacation_policy_A_assignation_date) { Date.new(2016,1,1) }
      #     let(:vacation_balancer_policy_A) do
      #       create(:time_off_policy, time_off_category: vacation_category,
      #         amount: vacation_balancer_policy_A_amount,
      #         end_day: 1,
      #         end_month: 1,
      #         years_to_effect: 1
      #       )
      #     end
      #     before(:each) do
      #       create_policy_balances
      #     end
      #     context ' and the time off ends in the same day of the validity date' do
      #       before do
      #         create(:time_off,
      #           start_time: Time.zone.parse('1/1/2017 00:30:00'),
      #           end_time: Time.zone.parse('1/1/2017 1:30:00'),
      #           employee: employee,
      #           time_off_category: vacation_category
      #         )
      #         update_balances
      #         subject
      #       end
      #       it do
      #          expect(JSON.parse(response.body)).to eq(
      #            [
      #              {
      #                'employee' => employee_id,
      #                'category' => "vacation",
      #                'periods' =>
      #                  [
      #                      {
      #                        'type' => "balancer",
      #                        'start_date' => '2016-01-01',
      #                        'validity_date' => '2017-01-01',
      #                        'amount_taken' => 60,
      #                        'period_result' => 40,
      #                        'balance' => 100
      #                      },
      #                      {
      #                        'type' => "balancer",
      #                        'start_date' => '2017-01-01',
      #                        'validity_date' => '2018-01-01',
      #                        'amount_taken' => 0,
      #                        'period_result' => 100,
      #                        'balance' => 100
      #                      }
      #                  ]
      #              }
      #            ]
      #          )
      #       end
      #     end
      #     context 'and the time off ends in the same day of the validity date' do
      #       before do
      #         create(:time_off,
      #           start_time: Time.zone.parse('1/1/2017 23:30:00'),
      #           end_time: Time.zone.parse('2/1/2017 00:30:00'),
      #           employee: employee,
      #           time_off_category: vacation_category
      #         )
      #         create_policy_balances
      #         update_balances
      #         subject
      #       end
      #       it do
      #          expect(JSON.parse(response.body)).to eq(
      #            [
      #              {
      #                'employee' => employee_id,
      #                'category' => "vacation",
      #                'periods' =>
      #                  [
      #                      {
      #                        'type' => "balancer",
      #                        'start_date' => '2016-01-01',
      #                        'validity_date' => '2017-01-01',
      #                        'amount_taken' => 30,
      #                        'period_result' => 70,
      #                        'balance' => 100
      #                      },
      #                      {
      #                        'type' => "balancer",
      #                        'start_date' => '2017-01-01',
      #                        'validity_date' => '2018-01-01',
      #                        'amount_taken' => 30,
      #                        'period_result' => 70,
      #                        'balance' => 70
      #                      }
      #                  ]
      #              }
      #            ]
      #          )
      #       end
      #     end
      #   end
      # end

      #TODO: Uncomment and fix specs
      # context 'when there is a time off that begins in the current period after previous period validity date' do
      #   let(:vacation_policy_A_assignation_date) { Time.now - 2.years }
      #   before do
      #     create_policy_balances
      #     create(:time_off, start_time: Time.zone.parse('2/4/2016 00:00:00'),
      #       end_time: Time.zone.parse('2/4/2016 02:30:00'), employee: employee,
      #       time_off_category: vacation_category
      #     )
      #     update_balances
      #   end
      #   it do
      #     subject
      #      expect(JSON.parse(response.body)).to eq(
      #        [
      #          {
      #            'employee' => employee_id,
      #            'category' => "vacation",
      #            'periods' =>
      #              [
      #                  {
      #                    'type' => "balancer",
      #                    'start_date' => '2015-01-01',
      #                    'validity_date' => '2016-04-01',
      #                    'amount_taken' => 0,
      #                    'period_result' => 100,
      #                    'balance' => 100
      #                  },
      #                  {
      #                    'type' => "balancer",
      #                    'start_date' => '2016-01-01',
      #                    'validity_date' => '2017-04-01',
      #                    'amount_taken' => 100,
      #                    'period_result' => 0,
      #                    'balance' => -50
      #                  },
      #                  {
      #                    'type' => "balancer",
      #                    'start_date' => '2017-01-01',
      #                    'validity_date' => '2018-04-01',
      #                    'amount_taken' => 50,
      #                    'period_result' => 50,
      #                    'balance' => 50
      #                  },
      #              ]
      #          }
      #        ]
      #      )
      #   end
      # end
      # context 'when there are negative balances from previous periods' do
      #   before do
      #     create(:time_off, start_time: Time.zone.parse('1/12/2016 00:00:00'),
      #       end_time: Time.zone.parse('1/12/2016 02:30:00'), employee: employee,
      #       time_off_category: vacation_category
      #     )
      #     create_policy_balances
      #     update_balances
      #   end
      #    it do
      #      subject
      #      expect(JSON.parse(response.body)).to eq(
      #        [
      #          {
      #            'employee' => employee_id,
      #            'category' => "vacation",
      #            'periods' =>
      #              [
      #                  {
      #                    'type' => "balancer",
      #                    'start_date' => '2016-01-01',
      #                    'validity_date' => '2017-04-01',
      #                    'amount_taken' => 100,
      #                    'period_result' => 0,
      #                    'balance' => -50
      #                  },
      #                  {
      #                    'type' => "balancer",
      #                    'start_date' => '2017-01-01',
      #                    'validity_date' => '2018-04-01',
      #                    'amount_taken' => 50,
      #                    'period_result' => vacation_balancer_policy_A_amount - 50,
      #                    'balance' => vacation_balancer_policy_A_amount - 50
      #                  }
      #              ]
      #          }
      #        ]
      #      )
      #    end
      # end

      # context 'when there are many previous period with active amounts at the beginning of the current period' do
      #   let(:vacation_balancer_policy_A) do
      #     create(:time_off_policy, :with_end_date, time_off_category: vacation_category,
      #       amount: vacation_balancer_policy_A_amount, years_to_effect: 2
      #     )
      #   end
      #   let(:vacation_policy_A_assignation_date) { Time.now - 2.years }
      #   before do
      #     create(:time_off, start_time: Time.zone.parse('31/12/2015 23:30:00'),
      #       end_time: Time.zone.parse('1/1/2016 00:30:00'), employee: employee,
      #       time_off_category: vacation_category)
      #     create_policy_balances
      #     update_balances
      #     subject
      #   end
      #   it do
      #      expect(JSON.parse(response.body)).to eq(
      #        [
      #          {
      #            'employee' => employee_id,
      #            'category' => "vacation",
      #            'periods' =>
      #              [
      #                  {
      #                    'type' => "balancer",
      #                    'start_date' => '2014-01-01',
      #                    'validity_date' => '2016-04-01',
      #                    'amount_taken' => 60,
      #                    'period_result' => 40,
      #                    'balance' => 100
      #                  },
      #                  {
      #                    'type' => "balancer",
      #                    'start_date' => '2015-01-01',
      #                    'validity_date' => '2017-04-01',
      #                    'amount_taken' => 0,
      #                    'period_result' => 100,
      #                    'balance' => 170
      #                  },
      #                  {
      #                    'type' => "balancer",
      #                    'start_date' => '2016-01-01',
      #                    'validity_date' => '2018-04-01',
      #                    'amount_taken' => 0,
      #                    'period_result' => 100,
      #                    'balance' => 200
      #                  },
      #                  {
      #                    'type' => "balancer",
      #                    'start_date' => '2017-01-01',
      #                    'validity_date' => '2019-04-01',
      #                    'amount_taken' => 0,
      #                    'period_result' => 100,
      #                    'balance' => 200
      #                  }
      #              ]
      #          }
      #        ]
      #      )
      #   end
      # end
    end

    #TODO: Uncomment and fix specs
    # context 'counter type' do
    #   let(:emergency_category) do
    #     create(:time_off_category, account: Account.current, name: 'emergency')
    #   end
    #   let(:emergency_counter_policy) do
    #      create(:time_off_policy, :as_counter, time_off_category: emergency_category)
    #   end

    #   let(:emergency_policy_assignation_date) { Time.now }
    #   let!(:emergency_policy_assignation) do
    #     create(:employee_time_off_policy,
    #       employee: employee, effective_at: emergency_policy_assignation_date,
    #       time_off_policy: emergency_counter_policy
    #     )
    #   end
    #   context 'when a category has current but not next period in the system already' do
    #     before do
    #       create_policy_balances
    #       subject
    #     end
    #     it do
    #       expect(JSON.parse(response.body)).to eq(
    #         [
    #           {
    #             'employee' => employee_id,
    #             'category' => "emergency",
    #             'periods' => [
    #                 {
    #                   'type' => "counter",
    #                   'start_date' => '2016-01-01',
    #                   'validity_date' => nil,
    #                   'amount_taken' => 0,
    #                   'period_result' => 0,
    #                   'balance' => 0
    #                 },
    #                 {
    #                   'type' => "counter",
    #                   'start_date' => '2017-01-01',
    #                   'validity_date' => nil,
    #                   'amount_taken' => 0,
    #                   'period_result' => 0,
    #                   'balance' => 0
    #                 },
    #             ]
    #           }
    #         ]
    #       )
    #     end
    #   end


    #   context 'when the category has current and next period in the system and a time off' do
    #     before do
    #       create_policy_balances
    #       create(:time_off, start_time: Time.zone.parse('31/12/2016 23:30:00'),
    #         end_time: Time.zone.parse('1/1/2017 00:30:00'), employee: employee,
    #         time_off_category: emergency_category
    #       )
    #       update_balances
    #       subject
    #     end
    #     it do
    #       expect(JSON.parse(response.body)).to eq(
    #         [
    #           {
    #             'employee' => employee_id,
    #             'category' => "emergency",
    #             'periods' => [
    #                 {
    #                   'type' => "counter",
    #                   'start_date' => '2016-01-01',
    #                   'validity_date' => nil,
    #                   'amount_taken' => 30,
    #                   'period_result' => -30,
    #                   'balance' => -30
    #                 },
    #                 {
    #                   'type' => "counter",
    #                   'start_date' => '2017-01-01',
    #                   'validity_date' => nil,
    #                   'amount_taken' => 30,
    #                   'period_result' => -30,
    #                   'balance' => -30
    #                 }
    #             ]
    #           }
    #         ]
    #       )
    #     end
    #   end
    # end
  end
end

require "rails_helper"

RSpec.describe BalanceOverview::Generate do
  describe ".call" do
    subject(:generate) { described_class.call(employee.reload, **params) }

    let_it_be(:account) { create(:account, create_presence_policy: false) }
    let_it_be(:hired_date) { Date.new(2018, 1, 1) }
    let_it_be(:query_date) { hired_date + 2.months }

    let_it_be(:day_duration) { 60 * 60 * 8 } # 8 hours
    let_it_be(:vacation_days) { 10 }
    let_it_be(:vacation_minutes) { day_duration * vacation_days }

    let_it_be(:presence_policy) do
      create(
        :presence_policy,
        :with_time_entries,
        account: account,
        occupation_rate: 1.0,
        default_full_time: true,
        standard_day_duration: day_duration,
        number_of_days: 7,
        working_days: (1..7).to_a,
        hours: [["00:00", "24:00"]],
      )
    end

    let_it_be(:event_params) do
      {
        effective_at: hired_date,
        event_type: "hired",
        time_off_policy_amount: vacation_days,
        employee: {},
        presence_policy_id: presence_policy.id,
        employee_attributes: [
          {
            value: 1.0,
            attribute_name: "occupation_rate",
          },
          {
            value: "John",
            attribute_name: "firstname",
          },
          {
            value: "Smith",
            attribute_name: "lastname",
          },
        ],
      }
    end

    let_it_be(:hire_employee) do
      # TODO: refactor service to not rely on Account.current
      Account.current = account
      Events::WorkContract::Create.call(event_params)
    end

    let_it_be(:employee) { hire_employee.employee }

    let(:params) do
      {
        date: query_date,
        category: filter_category,
      }.compact
    end

    let(:filter_category) { nil }

    let(:mapped_values) do
      generate.map(&method(:period_presenter))
    end

    let(:vacation_category) { account.time_off_categories.vacation.first }

    def period_presenter(period)
      { category: period.category.name, result: period.balance_result }
    end

    it "responds to employee method" do
      expect(generate).to all(respond_to(:employee))
    end

    context "when there is one category" do
      it "returns correct values" do
        expect(mapped_values).to contain_exactly(
          {
            category: "vacation",
            result: vacation_minutes,
          }
        )
      end

      context "when there is timeoff" do
        let(:time_off_minutes) { 60 * 3 } # 3 hours

        let(:vacation_end) do
          vacation_start + time_off_minutes.minutes
        end

        before do
          create(:time_off,
            start_time: vacation_start,
            end_time: vacation_end,
            time_off_category: vacation_category,
            employee: employee
          ) do |time_off|
            TimeOffs::Approve.call(time_off)
          end
        end

        context "this year" do
          let(:vacation_start) do
            hired_date.at_midnight + 1.month
          end

          it "returns correct values" do
            expect(mapped_values).to contain_exactly(
              {
                category: "vacation",
                result: vacation_minutes - time_off_minutes,
              }
            )
          end
        end

        context "next year" do
          let(:vacation_start) do
            hired_date.at_midnight + 1.year
          end

          it "returns correct values" do
            expect(mapped_values).to contain_exactly(
              {
                category: "vacation",
                result: vacation_minutes - time_off_minutes,
              }
            )
          end
        end

        context "starting this year and ending next year" do
          let(:year_end) { hired_date.end_of_year }

          let(:vacation_start) do
            year_end - 1.hour
          end

          it "returns correct values" do
            expect(mapped_values).to contain_exactly(
              {
                category: "vacation",
                result: vacation_minutes - time_off_minutes,
              }
            )
          end
        end
      end

      context "when there is adjustment event" do
        let(:adjustment_minutes) { 500 }

        before do
          Events::Adjustment::Create.call(
            effective_at: adjustment_date,
            event_type: "adjustment_of_balances",
            employee: {
              id: employee.id,
              type: "employee",
            },
            employee_attributes: [
              {
                type: "employee_attribute",
                attribute_name: "adjustment",
                value: adjustment_minutes,
              },
            ]
          )
        end

        context "in the current period" do
          let(:adjustment_date) { hired_date + 1.month}

          it "returns correct values" do
            expect(mapped_values).to contain_exactly(
              {
                category: "vacation",
                result: vacation_minutes + adjustment_minutes,
              }
            )
          end
        end

        context "in the next period" do
          let(:adjustment_date) { hired_date + 1.year}

          it "returns correct values" do
            expect(mapped_values).to contain_exactly(
              {
                category: "vacation",
                result: vacation_minutes,
              }
            )
          end
        end
      end
    end

    context "when there are many categories" do
      let(:emergency_category) do
        create(:time_off_category, account: account, name: "emergency")
      end
      let(:emergency_counter_policy) do
        create(:time_off_policy, :as_counter, time_off_category: emergency_category)
      end

      before do
        create(:employee_time_off_policy,
          employee: employee, effective_at: hired_date,
          time_off_policy: emergency_counter_policy
        )
      end

      it "returns correct values" do
        expect(mapped_values).to contain_exactly(
          {
            category: "vacation",
            result: vacation_minutes,
          },
          {
            category: "emergency",
            result: 0,
          }
        )
      end

      context "when filtered by category" do
        let(:filter_category) { "vacation" }

        it "returns correct values" do
          expect(mapped_values).to contain_exactly(
            {
              category: "vacation",
              result: vacation_minutes,
            }
          )
        end
      end

      context "and both have time offs" do
        let(:time_off_minutes) { 60 * 3 } # 3 hours

        let(:vacation_start) do
          hired_date.at_midnight + 1.month
        end

        let(:vacation_end) do
          vacation_start + time_off_minutes.minutes
        end

        let(:emergency_timeoff_start) do
          vacation_end + 1.day
        end

        let(:emergency_timeoff_end) do
          emergency_timeoff_start + time_off_minutes.minutes
        end

        before do
          create(:time_off,
            start_time: vacation_start,
            end_time: vacation_end,
            time_off_category: vacation_category,
            employee: employee
          )
          create(:time_off,
            start_time: emergency_timeoff_start,
            end_time: emergency_timeoff_end,
            time_off_category: emergency_category,
            employee: employee
          )
          TimeOff.all.map { |time_off| TimeOffs::Approve.call(time_off) }
        end

        it "returns correct values" do
          expect(mapped_values).to contain_exactly(
            {
              category: "vacation",
              result: vacation_minutes - time_off_minutes,
            },
            {
              category: "emergency",
              result: 0 - time_off_minutes,
            }
          )
        end
      end
    end

    context "when hired_date is in the future" do
      let_it_be(:query_date) { hired_date - 1.month }

      it "returns correct values" do
        expect(mapped_values).to contain_exactly(
          {
            category: "vacation",
            result: 0,
          }
        )
      end
    end

    context "when there is contract end" do
      let_it_be(:contract_end_date) { hired_date + 3.months }

      let_it_be(:contract_end_params) do
        {
          effective_at: contract_end_date,
          event_type: "contract_end",
          employee: {
            id: employee.id,
          },
        }
      end

      before_all do
        CreateEvent.new(contract_end_params, []).call
      end

      context "in the future" do
        let_it_be(:query_date) { contract_end_date - 1.month }

        it "returns correct values" do
          expect(mapped_values).to contain_exactly(
            {
              category: "vacation",
              result: vacation_minutes,
            }
          )
        end
      end

      context "in the past" do
        let_it_be(:query_date) { contract_end_date + 1.month }

        it "returns correct values" do
          expect(mapped_values).to contain_exactly(
            {
              category: "vacation",
              result: 0,
            }
          )
        end
      end
    end
  end
end

require "rails_helper"

RSpec.describe CreateRegisteredWorkingTime do
  include_context "shared_context_timecop_helper"

  subject { described_class.new(date, employees_ids).call }

  let(:account) { create(:account) }
  let(:employee) { create(:employee, account: account) }
  let(:employees) { [employee] }
  let(:employees_ids) { employees.map(&:id) }

  let(:employee_rwt) { RegisteredWorkingTime.where(employee_id: employee.id) }

  let(:pp_one_week_work_from_mon_to_fri) do
    create(:presence_policy, :with_time_entries,
      number_of_days: 7,
      working_days: [1, 2, 3, 4, 5],
      hours: [
        %w(08:00 12:00),
        %w(13:00 17:00)
      ]
    )
  end

  let(:pp_one_week_work_only_tue) do
    create(:presence_policy, :with_time_entries,
      number_of_days: 7,
      working_days: [2],
      hours: [
        %w(08:00 12:00),
        %w(13:00 17:00)
      ]
    )
  end

  let(:pp_one_week_work_only_wed_afternoon) do
    create(:presence_policy, :with_time_entries,
      number_of_days: 7,
      working_days: [3],
      hours: [
        %w(13:00 17:00)
      ]
    )
  end

  before do
    Timecop.freeze(2016, 8, 10)
  end

  context "when the employee have policies of 7 days" do
    context "working from Monday to Friday" do
      let!(:employee_presence_policy) do
        # To be sure we don't assign it on Monday
        effective_at = 10.months.ago.to_date.beginning_of_week + 1

        create(:employee_presence_policy,
          presence_policy: pp_one_week_work_from_mon_to_fri,
          employee: employee,
          effective_at: effective_at,
          order_of_start_day: effective_at.cwday
        )
      end

      context "on Sunday" do
        let(:date) { Date.today.beginning_of_week - 1 }

        it "should create registred working time without time entries" do
          expect { subject }.to change { employee_rwt.count }.by(1)
          rwt = employee_rwt.first!

          expect(rwt.date).to eq(date)
          expect(rwt.date.cwday).to eq(7)
          expect(rwt.time_entries).to match_array([])
        end
      end

      context "on Monday" do
        let(:date) { Date.today.beginning_of_week }

        it "should create registred working time with time entries" do
          expect { subject }.to change { employee_rwt.count }.by(1)
          rwt = employee_rwt.first!

          expect(rwt.date).to eq(date)
          expect(rwt.date.cwday).to eq(1)
          expect(rwt.time_entries).to match_array([
            { "start_time" => "08:00:00", "end_time" => "12:00:00" },
            { "start_time" => "13:00:00", "end_time" => "17:00:00" }
          ])
        end
      end

      context "with time-off" do
        let(:time_off_category) do
          account.time_off_categories.where(name: "vacation").first!
        end

        let(:time_off_policy) do
          create(:time_off_policy,
            time_off_category: time_off_category,
            policy_type: "balancer",
            amount: 960
          )
        end

        let!(:employee_top) do
          employee.employee_time_off_policies.create!(
            time_off_policy_id: time_off_policy.id,
            effective_at: employee.first_employee_event.effective_at
          )
        end

        context "full day from Friday to Monday" do
          let!(:time_off) do
            create(:time_off, employee: employee, time_off_category: time_off_category,
              start_time: (Date.today.beginning_of_week - 3).at_beginning_of_day,
              end_time: (Date.today.beginning_of_week + 1).at_beginning_of_day
            )
          end

          context "on Friday" do
            let(:date) { Date.today.beginning_of_week - 3 }

            it "should create registred working time without time entries" do
              expect { subject }.to change { employee_rwt.count }.by(1)
              rwt = employee_rwt.first!

              expect(rwt.date).to eq(date)
              expect(rwt.date.cwday).to eq(5)
              expect(rwt.time_entries).to match_array([])
            end
          end

          context "on Sunday" do
            let(:date) { Date.today.beginning_of_week - 1 }

            it "should create registred working time without time entries" do
              expect { subject }.to change { employee_rwt.count }.by(1)
              rwt = employee_rwt.first!

              expect(rwt.date).to eq(date)
              expect(rwt.date.cwday).to eq(7)
              expect(rwt.time_entries).to match_array([])
            end
          end

          context "on Tuesday" do
            let(:date) { Date.today.beginning_of_week + 1 }

            it "should create registred working time with time entries" do
              expect { subject }.to change { employee_rwt.count }.by(1)
              rwt = employee_rwt.first!

              expect(rwt.date).to eq(date)
              expect(rwt.date.cwday).to eq(2)
              expect(rwt.time_entries).to match_array([
                { "start_time" => "08:00:00", "end_time" => "12:00:00" },
                { "start_time" => "13:00:00", "end_time" => "17:00:00" }
              ])
            end
          end
        end

        context "half day on Tuesday" do
          let(:date) { Date.today.beginning_of_week + 1 }

          let!(:time_off) do
            create(:time_off, employee: employee, time_off_category: time_off_category,
              start_time: (Date.today.beginning_of_week + 1).at_noon - 1.hour,
              end_time: (Date.today.beginning_of_week + 2).at_beginning_of_day
            )
          end

          it "should create registred working time with time entries" do
            expect { subject }.to change { employee_rwt.count }.by(1)
            rwt = employee_rwt.first!

            expect(rwt.date).to eq(date)
            expect(rwt.date.cwday).to eq(2)
            expect(rwt.time_entries).to match_array([
              { "start_time" => "08:00:00", "end_time" => "11:00:00" },
            ])
          end
        end
      end
    end

    context "and have bank holidays" do
      let!(:employee_working_place) do
        create(:employee_working_place, employee: employee, effective_at: date)
      end

      let(:working_place) { employee_working_place.working_place }

      let!(:holiday_policy) do
        create(:holiday_policy, account: account, country: "ch", region: "vd")
      end

      let!(:employee_presence_policy) do
        # To be sure we don't assign it on Monday
        effective_at = 10.months.ago.to_date.beginning_of_week + 1

        create(:employee_presence_policy,
               presence_policy: pp_one_week_work_from_mon_to_fri,
               employee: employee,
               effective_at: effective_at,
               order_of_start_day: effective_at.cwday
              )
      end

      before do
        working_place.holiday_policy = holiday_policy
        working_place.save!
      end

      context "on a working day" do
        context "only in the region" do
          let(:date) { Date.new(2016, 1, 1) }


          it "should create registred working time without time entries" do
            expect { subject }.to change { employee_rwt.count }.by(1)
            rwt = employee_rwt.first!

            expect(rwt.date).to eq(date)
            expect(rwt.date.cwday).to eq(5)
            expect(rwt.time_entries).to match_array([])
          end
        end

        context "in the country" do
          let(:date) { Date.new(2016, 8, 1) }

          it "should create registred working time without time entries" do
            expect { subject }.to change { employee_rwt.count }.by(1)
            rwt = employee_rwt.first!

            expect(rwt.date).to eq(date)
            expect(rwt.date.cwday).to eq(1)
            expect(rwt.time_entries).to match_array([])
          end
        end
      end

      context "not on a working day" do
        let(:date) { Date.new(2016, 1, 2) }

        it "should create registred working time without time entries" do
          expect { subject }.to change { employee_rwt.count }.by(1)
          rwt = employee_rwt.first!

          expect(rwt.date).to eq(date)
          expect(rwt.date.cwday).to eq(6)
          expect(rwt.time_entries).to match_array([])
        end
      end

      context "on another day" do
        let(:date) { Date.new(2016, 1, 4) }

        it "should create registred working time without time entries" do
          expect { subject }.to change { employee_rwt.count }.by(1)
          rwt = employee_rwt.first!

          expect(rwt.date).to eq(date)
          expect(rwt.date.cwday).to eq(1)
          expect(rwt.time_entries).to match_array([
            { "start_time" => "08:00:00", "end_time" => "12:00:00" },
            { "start_time" => "13:00:00", "end_time" => "17:00:00" }
          ])
        end
      end
    end
  end
end

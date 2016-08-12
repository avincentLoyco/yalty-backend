require 'rails_helper'

RSpec.describe AddRegisteredWorkingTimes do
  include_context 'shared_context_timecop_helper'

  subject { described_class.perform_now }

  let(:date) { Time.zone.today - 1.day }
  let(:account) { create(:account) }
  let(:first_employee) { create(:employee, account: account) }
  let(:second_employee) { create(:employee, account: account) }
  let(:presence_policy_a) { create(:presence_policy, :with_presence_day, account: account) }
  let(:presence_policy_b) { create(:presence_policy, :with_presence_day, account: account) }
  let!(:epp_a) do
    create(:employee_presence_policy,
      presence_policy: presence_policy_a,
      employee: first_employee,
      effective_at: date
    )
  end
  let!(:epp_b) do
    create(:employee_presence_policy,
      presence_policy: presence_policy_b,
      employee: second_employee,
      effective_at: date
    )
  end

  context 'when the employees have presence days with time entries' do
    before(:each)  do
      day_a = create(:presence_day, order: 1, presence_policy: presence_policy_a)
      create(:time_entry, presence_day: day_a, start_time: '1:00', end_time: '2:00')
      create(:time_entry, presence_day: day_a, start_time: '3:00', end_time: '4:00')
      day_b = create(:presence_day, order: 1, presence_policy: presence_policy_b)
      create(:time_entry, presence_day: day_b, start_time: '5:00', end_time: '6:00')
    end

    context 'when there are days without registered working hours to add' do

      context 'and no time offs' do
        context 'when policy has length different than 7' do
          before do
            Timecop.freeze(2016, 1, 14, 0, 0)
            day = create(:presence_day, order: 2, presence_policy: presence_policy_b)
            create(:time_entry, presence_day: day, start_time: '2:00', end_time: '10:00')
          end
          after { Timecop.return }

          it 'should create registered working time with proper time entries' do
            expect { subject }.to change { RegisteredWorkingTime.count }.from(0).to(2)
            first_employee_rwt = RegisteredWorkingTime.find_by(employee_id: first_employee.id)
            expect(first_employee_rwt.date).to eq(Date.new(2016, 1, 13))
            expect(first_employee_rwt.employee_id).to eq(first_employee.id)
            expect(first_employee_rwt.time_entries).to match_array([])
            first_employee_rwt = RegisteredWorkingTime.find_by(employee_id: second_employee.id)
            expect(first_employee_rwt.date).to eq(Date.new(2016, 1, 13))
            expect(first_employee_rwt.employee_id).to eq(second_employee.id)
            expect(first_employee_rwt.time_entries).to match_array(
              [
                {
                  'start_time' => "02:00:00",
                  'end_time' => "10:00:00"
                }
              ]
            )
          end
        end

        it do
          expect { subject }.to change { RegisteredWorkingTime.count }.from(0).to(2)
          first_employee_rwt = RegisteredWorkingTime.find_by(employee_id: first_employee.id)
          expect(first_employee_rwt.date).to eq(date)
          expect(first_employee_rwt.employee_id).to eq(first_employee.id)
          expect(first_employee_rwt.time_entries).to match_array(
            [
              {
                'start_time' => "01:00:00",
                'end_time' => "02:00:00"
              },
              {
                'start_time' => "03:00:00",
                'end_time' => "04:00:00"
              }
            ]
          )
          expect(first_employee_rwt.schedule_generated).to eq(true)
          second_employee_rwt = RegisteredWorkingTime.find_by(employee_id: second_employee.id)
          expect(second_employee_rwt.date).to eq(date)
          expect(second_employee_rwt.employee_id).to eq(second_employee.id)
          expect(second_employee_rwt.time_entries).to match_array(
            [
              {
                'start_time' => "05:00:00",
                'end_time' => "06:00:00"
              }
            ]
          )
          expect(second_employee_rwt.schedule_generated).to eq(true)
        end
      end

      context 'and time offs' do
        before do
          create(:time_off,
            employee: first_employee ,
            start_time: date + 1.hour + 20.minutes,
            end_time: date + 1.hour + 40.minutes,
          )
          create(:time_off,
            employee: second_employee ,
            start_time: date + 5.hours + 20.minutes,
            end_time: date + 5.hours + 40.minutes,
          )
        end
        it do
          expect { subject }.to change { RegisteredWorkingTime.count }.from(0).to(2)
          first_employee_rwt = RegisteredWorkingTime.find_by(employee_id: first_employee.id)
          expect(first_employee_rwt.date).to eq(date)
          expect(first_employee_rwt.employee_id).to eq(first_employee.id)
          expect(first_employee_rwt.time_entries).to match_array(
            [
              {
                'start_time' => "01:00:00",
                'end_time' => "01:20:00"
              },
              {
                'start_time' => "01:40:00",
                'end_time' => "02:00:00"
              },
              {
                'start_time' => "03:00:00",
                'end_time' => "04:00:00"
              }
            ]
          )
          expect(first_employee_rwt.schedule_generated).to eq(true)
          second_employee_rwt = RegisteredWorkingTime.find_by(employee_id: second_employee.id)
          expect(second_employee_rwt.date).to eq(date)
          expect(second_employee_rwt.employee_id).to eq(second_employee.id)
          expect(second_employee_rwt.time_entries).to match_array(
            [
              {
                'start_time' => "05:00:00",
                'end_time' => "05:20:00"
              },
              {
                'start_time' => "05:40:00",
                'end_time' => "06:00:00"
              }
            ]
          )
          expect(second_employee_rwt.schedule_generated).to eq(true)
        end
      end
    end
    context 'when there is a registered working time on that day for one empoyee' do
      let!(:rwt) { create(:registered_working_time, employee: first_employee , date: date) }
      it do
        expect { subject }
          .not_to change { RegisteredWorkingTime.where(employee_id: first_employee.id).count }
      end
      it do
        expect { subject }
          .to change { RegisteredWorkingTime.where(employee_id: second_employee.id).count }.by(1)
        second_employee_rwt = RegisteredWorkingTime.find_by(employee_id: second_employee.id)
        expect(second_employee_rwt.date).to eq(date)
        expect(second_employee_rwt.employee_id).to eq(second_employee.id)
        expect(second_employee_rwt.time_entries).to match_array(
          [
            {
              'start_time' => "05:00:00",
              'end_time' => "06:00:00"
            }
          ]
        )
        expect(second_employee_rwt.schedule_generated).to eq(true)
      end

      context 'and a time off for another' do
        before do
          create(:time_off,
            employee: second_employee ,
            start_time: date + 5.hours + 20.minutes,
            end_time: date + 5.hours + 40.minutes,
          )
        end

        it do
          expect { subject }
            .to change { RegisteredWorkingTime.where(employee_id: second_employee.id).count }.by(1)
          second_employee_rwt = RegisteredWorkingTime.find_by(employee_id: second_employee.id)
          expect(second_employee_rwt.date).to eq(date)
          expect(second_employee_rwt.employee_id).to eq(second_employee.id)
          expect(second_employee_rwt.time_entries).to match_array(
            [
              {
                'start_time' => "05:00:00",
                'end_time' => "05:20:00"
              },
              {
                'start_time' => "05:40:00",
                'end_time' => "06:00:00"
              }
            ]
          )
          expect(second_employee_rwt.schedule_generated).to eq(true)
        end
      end
    end
  end

  context 'when there is a holiday on that day for one employee and the employee has a time entry' do
    before(:each)  do
      day_a = create(:presence_day, order: 2, presence_policy: presence_policy_a)
      create(:time_entry, presence_day: day_a, start_time: '1:00', end_time: '2:00')
      day_b = create(:presence_day, order: 2, presence_policy: presence_policy_b)
      create(:time_entry, presence_day: day_b, start_time: '5:00', end_time: '6:00')
    end

    let!(:holiday_policy) do
      HolidayPolicy.create(name: 'vactions', account: account, country: 'ch', region: 'zh')
    end
    let(:date_of_job_run) { Time.zone.now - 1.day }

    before do
      Timecop.freeze(2016, 1, 2, 0, 0)
      working_place.update_attribute(:holiday_policy_id, holiday_policy.id)
    end

    after { Timecop.return }

    context 'and there is a registered working time for another' do
      let(:working_place) { employee_working_place.working_place }
      let(:employee_working_place) do
        create(:employee_working_place, employee: second_employee, effective_at: 6.years.ago)
      end
      let!(:rwt) { create(:registered_working_time, employee: first_employee , date: date_of_job_run) }
      it do
        expect { subject }
          .not_to change { RegisteredWorkingTime.where(employee_id: first_employee.id).count }
        first_employee_rwt = RegisteredWorkingTime.find_by(employee_id: first_employee.id)
        expect(first_employee_rwt.date).to eq(date_of_job_run)
        expect(first_employee_rwt.employee_id).to eq(first_employee.id)
        expect(first_employee_rwt.time_entries).to match_array(
          [
            {
              'start_time' => "10:00:00",
              'end_time' => "14:00:00"
            },
            {
              'start_time' => "15:00:00",
              'end_time' => "20:00:00"
            }
          ]
        )
        expect(first_employee_rwt.schedule_generated).to eq(false)
      end
      it do
        expect { subject }
          .to change { RegisteredWorkingTime.where(employee_id: second_employee.id).count }.by(1)
        second_employee_rwt = RegisteredWorkingTime.find_by(employee_id: second_employee.id)
        expect(second_employee_rwt.date).to eq(date_of_job_run)
        expect(second_employee_rwt.employee_id).to eq(second_employee.id)
        expect(second_employee_rwt.time_entries).to match_array( [] )
        expect(second_employee_rwt.schedule_generated).to eq(true)
      end
    end

    context 'and a normal day for the other employee' do
      let(:working_place) { employee_working_place.working_place }
      let(:employee_working_place) do
        create(:employee_working_place, employee: second_employee, effective_at: 6.years.ago)
      end

      it do
        expect { subject }
          .to change { RegisteredWorkingTime.where(employee_id: first_employee.id).count }.by(1)
        first_employee_rwt = RegisteredWorkingTime.find_by(employee_id: first_employee.id)
        expect(first_employee_rwt.date).to eq(date_of_job_run)
        expect(first_employee_rwt.employee_id).to eq(first_employee.id)
        expect(first_employee_rwt.time_entries).to match_array(
          [
            {
              'start_time' => "01:00:00",
              'end_time' => "02:00:00"
            }
          ]
        )
        expect(first_employee_rwt.schedule_generated).to eq(true)
      end

      it do
        expect { subject }
          .to change { RegisteredWorkingTime.where(employee_id: second_employee.id).count }.by(1)
        second_employee_rwt = RegisteredWorkingTime.find_by(employee_id: second_employee.id)
        expect(second_employee_rwt.date).to eq(date_of_job_run)
        expect(second_employee_rwt.employee_id).to eq(second_employee.id)
        expect(second_employee_rwt.time_entries).to match_array( [] )
        expect(second_employee_rwt.schedule_generated).to eq(true)
      end
    end

    context 'and also the same employee a registered woring time also  ' do
      let(:working_place) { employee_working_place.working_place }
      let(:employee_working_place) do
        create(:employee_working_place, employee: first_employee, effective_at: 6.years.ago)
      end

      let!(:rwt) { create(:registered_working_time, employee: first_employee , date: date_of_job_run) }

      it do
        expect { subject }
          .not_to change { RegisteredWorkingTime.where(employee_id: first_employee.id).count }
        first_employee_rwt = RegisteredWorkingTime.find_by(employee_id: first_employee.id)
        expect(first_employee_rwt.date).to eq(date_of_job_run)
        expect(first_employee_rwt.employee_id).to eq(first_employee.id)
        expect(first_employee_rwt.time_entries).to match_array(
          [
            {
              'start_time' => "10:00:00",
              'end_time' => "14:00:00"
            },
            {
              'start_time' => "15:00:00",
              'end_time' => "20:00:00"
            }
          ]
        )
        expect(first_employee_rwt.schedule_generated).to eq(false)
      end

      it do
        expect { subject }
          .to change { RegisteredWorkingTime.where(employee_id: second_employee.id).count }.by(1)
        second_employee_rwt = RegisteredWorkingTime.find_by(employee_id: second_employee.id)
        expect(second_employee_rwt.date).to eq(date_of_job_run)
        expect(second_employee_rwt.employee_id).to eq(second_employee.id)
        expect(second_employee_rwt.time_entries).to match_array(
          [
            {
              'start_time' => "05:00:00",
              'end_time' => "06:00:00"
            }
          ]
        )
        expect(second_employee_rwt.schedule_generated).to eq(true)
      end
    end
  end

  context 'when the employees have no presence days with time entries' do
    it do
      expect { subject }.to change { RegisteredWorkingTime.count }.from(0).to(2)
      first_employee_rwt = RegisteredWorkingTime.find_by(employee_id: first_employee.id)
      expect(first_employee_rwt.date).to eq(date)
      expect(first_employee_rwt.employee_id).to eq(first_employee.id)
      expect(first_employee_rwt.time_entries).to match_array( [] )
      expect(first_employee_rwt.schedule_generated).to eq(true)
      second_employee_rwt = RegisteredWorkingTime.find_by(employee_id: second_employee.id)
      expect(second_employee_rwt.date).to eq(date)
      expect(second_employee_rwt.employee_id).to eq(second_employee.id)
      expect(second_employee_rwt.time_entries).to match_array( [] )
      expect(second_employee_rwt.schedule_generated).to eq(true)
    end
  end
end

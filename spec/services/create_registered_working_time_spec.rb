require 'rails_helper'

RSpec.describe CreateRegisteredWorkingTime do
  include_context 'shared_context_timecop_helper'

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
    Timecop.freeze(2016, 1, 14)
  end

  context 'when the employee have policies of 7 days' do
    context 'working from Monday to Friday' do
      let!(:employee_presence_policy) do
        # To be sure we don't assign it on Monday
        effective_at = 3.months.ago.to_date.beginning_of_week + 1

        create(:employee_presence_policy,
          presence_policy: pp_one_week_work_from_mon_to_fri,
          employee: employee,
          effective_at: effective_at,
          order_of_start_day: effective_at.cwday
        )
      end

      context 'on Sunday' do
        let(:date) { Date.today.beginning_of_week - 1 }

        it 'should create registred working time without time entries' do
          expect { subject }.to change { employee_rwt.count }.by(1)
          rwt = RegisteredWorkingTime.where(employee_id: employee.id).first!

          expect(rwt.date).to eq(date)
          expect(rwt.date.cwday).to eq(7)
          expect(rwt.time_entries).to match_array([])
        end
      end

      context 'on Monday' do
        let(:date) { Date.today.beginning_of_week }

        it 'should create registred working time with time entries' do
          expect { subject }.to change { employee_rwt.count }.by(1)
          rwt = RegisteredWorkingTime.where(employee_id: employee.id).first!

          expect(rwt.date).to eq(date)
          expect(rwt.date.cwday).to eq(1)
          expect(rwt.time_entries).to match_array([
            { 'start_time' => '08:00:00', 'end_time' => '12:00:00' },
            { 'start_time' => '13:00:00', 'end_time' => '17:00:00' }
          ])
        end
      end
    end
  end
end

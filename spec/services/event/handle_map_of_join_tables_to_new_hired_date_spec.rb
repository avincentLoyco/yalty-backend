require 'rails_helper'

RSpec.describe HandleMapOfJoinTablesToNewHiredDate, type: :service do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'
  subject { HandleMapOfJoinTablesToNewHiredDate.new(employee, hired_date).call }

  describe 'For EmployeeTimeOffPolicy' do
    let(:employee) { create(:employee) }
    let!(:second_policy) do
      create(:employee_time_off_policy, :with_employee_balance, employee: employee)
    end
    let!(:first_policy) do
      create(:employee_time_off_policy, :with_employee_balance, employee: employee)
    end
    let!(:first_balance) { first_policy.policy_assignation_balance }
    let!(:second_balance) { second_policy.policy_assignation_balance }
    let(:balances_ids) { subject[:employee_balances].map(&:id) }
    let(:join_tables_ids) { subject[:join_tables].map(&:id) }

    context 'when hired_date moved to past' do
      let(:hired_date) { employee.hired_date - 5.days }

      context 'and both employee time off policies are valid since hired date' do
        before do
          EmployeeTimeOffPolicy.all.update_all(effective_at: employee.hired_date)
          Employee::Balance.all.update_all(
            effective_at: employee.hired_date + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET
          )
        end

        it { expect(join_tables_ids).to include second_policy.id }
        it { expect(join_tables_ids).to include first_policy.id }
        it { expect(balances_ids).to include first_balance.id }
        it { expect(balances_ids).to include second_balance.id }

        it { expect(subject[:join_tables].size).to eq 2 }
        it { expect(subject[:employee_balances].size).to eq 2 }

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
        it { expect { subject }.to_not change { Employee::Balance.count } }
      end

      context 'and only one employee time off policy is valid since hired date' do
        before do
          first_policy.update!(effective_at: employee.hired_date)
          first_balance.update!(
            effective_at: employee.hired_date + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET
          )
        end

        it { expect(join_tables_ids).to_not include second_policy.id }
        it { expect(join_tables_ids).to include first_policy.id }
        it { expect(balances_ids).to include first_balance.id }
        it { expect(balances_ids).to_not include second_balance.id }

        it { expect(subject[:join_tables].size).to eq 1 }
        it { expect(subject[:employee_balances].size).to eq 1 }

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
        it { expect { subject }.to_not change { Employee::Balance.count } }
      end

      context 'and none of the employee time off policies are valid since hired date' do
        it { expect(join_tables_ids).to_not include second_policy.id }
        it { expect(join_tables_ids).to_not include first_policy.id }
        it { expect(balances_ids).to_not include second_balance.id }
        it { expect(balances_ids).to_not include first_balance.id }

        it { expect(subject[:join_tables].size).to eq 0 }
        it { expect(subject[:employee_balances].size).to eq 0 }

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
        it { expect { subject }.to_not change { Employee::Balance.count } }
      end
    end

    context 'when effective at moved to future' do
      let(:hired_date) { 5.days.since }

      context 'and there is only one employee time off policy per time off category' do
        it { expect(join_tables_ids).to include second_policy.id }
        it { expect(join_tables_ids).to include first_policy.id }
        it { expect(balances_ids).to include first_balance.id }
        it { expect(balances_ids).to include second_balance.id }

        it { expect(subject[:join_tables].map(&:effective_at).uniq).to eq [hired_date.to_date] }
        it { expect(subject[:join_tables].size).to eq 2 }
        it { expect(subject[:employee_balances].size).to eq 2 }

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
      end

      context 'and there are more than one employee time off policies per time off category' do
        let(:new_policy) do
          create(:time_off_policy, time_off_category: first_policy.time_off_category)
        end
        let!(:third_policy) do
          create(:employee_time_off_policy, :with_employee_balance,
            employee: employee, effective_at: first_policy.effective_at + 3.days,
            time_off_policy: new_policy)
        end

        let!(:third_balance) { third_policy.policy_assignation_balance }

        it { expect(join_tables_ids).to include second_policy.id }
        it { expect(join_tables_ids).to include third_policy.id }
        it { expect(join_tables_ids).to_not include first_policy.id }
        it { expect(balances_ids).to_not include first_balance.id}
        it { expect(balances_ids).to include second_balance.id }
        it { expect(balances_ids).to include third_balance.id }

        it { expect(subject[:join_tables].map(&:effective_at).uniq).to eq [hired_date.to_date] }
        it { expect(subject[:join_tables].size).to eq 2 }

        it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
        it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
      end
    end
  end

  describe 'For EmployeeWorkingPlace' do
    let(:employee) { create(:employee_with_working_place) }
    let!(:first_working_place) { employee.first_employee_working_place }

    context 'when there is one working place in the period' do
      context 'and hired_date moved to past' do
        let(:hired_date) { employee.hired_date - 5.days }

        context 'and employee working place was at hired date' do
          it { expect(subject[:join_tables].first.effective_at).to eq hired_date.to_date }
          it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        end

        context 'and employee working place wasn\'t at hired date' do
          before do
            employee.employee_working_places.first.update!(
              effective_at: employee.hired_date + 1.day)
          end

          it { expect(subject[:join_tables]).to eq [] }
          it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        end
      end

      context 'and hired_date moved to future' do
        let(:hired_date) { 5.days.since }

        it { expect(subject[:join_tables].first.effective_at).to eq hired_date.to_date }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
      end
    end

    context 'and employee has more employee working places but not in the period' do
      let(:hired_date) { 5.days.since }
      let!(:second_working_place) do
        create(:employee_working_place, employee: employee, effective_at: 1.week.since)
      end

      it { expect(subject[:join_tables].first.effective_at).to eq hired_date.to_date }

      it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
    end

    context 'when more working places is in period' do
      let!(:second_working_place) do
        create(:employee_working_place, employee: employee, effective_at: 1.week.since)
      end
      let!(:third_working_place) do
        create(:employee_working_place, employee: employee, effective_at: 2.weeks.since)
      end

      context 'and hired_date moved to past' do
        let(:hired_date) { 5.days.ago }

        it { expect(subject[:join_tables].first.id).to eq first_working_place.id }
        it { expect(subject[:join_tables].first.effective_at).to eq hired_date.to_date }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
      end

      context 'and effective at moved to future' do
        let(:hired_date) { 3.weeks.since }

        it { expect(subject[:join_tables].first.effective_at).to eq hired_date.to_date }
        it { expect(subject[:join_tables].first.id).to eq third_working_place.reload.id }

        it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-2) }
        it { expect { subject }.to change { EmployeeWorkingPlace.exists?(first_working_place.id) } }
        it do
          expect { subject }.to change { EmployeeWorkingPlace.exists?(second_working_place.id) }
        end
      end
    end
  end

  describe 'For EmployeePresencePolicy' do
    let(:employee) { create(:employee) }
    let!(:first_presence_policy) do
      create(:employee_presence_policy, employee: employee, effective_at: employee.hired_date)
    end

    context 'when there is one working place in the period' do
      context 'and hired_date moved to past' do
        let(:hired_date) { employee.hired_date - 5.days }

        context 'and employee presence policy was at hired date' do
          it { expect(subject[:join_tables].first.effective_at).to eq hired_date.to_date }
          it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
        end

        context 'and employee presence policy wasn\'t at hired date' do
          before do
            employee.employee_presence_policies.first.update!(
              effective_at: employee.hired_date + 1.day)
          end

          it { expect(subject[:join_tables]).to eq [] }
          it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
        end
      end

      context 'and hired_date moved to future' do
        let(:hired_date) { 5.days.since }

        it { expect(subject[:join_tables].first.effective_at).to eq hired_date.to_date }

        it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
      end
    end

    context 'and employee has more employee presence policy but not in the period' do
      let(:hired_date) { 5.days.since }
      let!(:second_presence_policy) do
        create(:employee_presence_policy, employee: employee, effective_at: 1.week.since)
      end

      it { expect(subject[:join_tables].first.effective_at).to eq hired_date.to_date }

      it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
    end

    context 'when more presence policies is in period' do
      let!(:second_presence_policy) do
        create(:employee_presence_policy, employee: employee, effective_at: 1.weeks.since)
      end
      let!(:third_presence_policy) do
        create(:employee_presence_policy, employee: employee, effective_at: 2.weeks.since)
      end

      context 'and hired_date moved to past' do
        let(:hired_date) { 5.days.ago }

        it { expect(subject[:join_tables].first.id).to eq first_presence_policy.id }
        it { expect(subject[:join_tables].first.effective_at).to eq hired_date.to_date }

        it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
      end

      context 'and effective at moved to future' do
        let(:hired_date) { 3.weeks.since }

        it { expect(subject[:join_tables].first.effective_at).to eq hired_date.to_date }
        it { expect(subject[:join_tables].first.id).to eq third_presence_policy.reload.id }

        it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-2) }
        it do
          expect { subject }.to change { EmployeePresencePolicy.exists?(second_presence_policy.id) }
        end
        it do
          expect { subject }.to change { EmployeePresencePolicy.exists?(first_presence_policy.id) }
        end
      end
    end
  end
end

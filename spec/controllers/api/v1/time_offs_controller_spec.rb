require 'rails_helper'

RSpec.describe API::V1::TimeOffsController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  before { time_off_category.update!(account: Account.current) }
  let(:policy) { create(:presence_policy, :with_presence_day, account: Account.current) }
  let(:employee) do
    create(:employee, :with_time_off_policy, :with_presence_policy, account: account,
      presence_policy: policy
    )
  end
  let(:employee_time_off_policy) { employee.employee_time_off_policies.first }
  let(:time_off_category) { employee_time_off_policy.time_off_policy.time_off_category }
  let!(:assignation_balance) do
    create(:employee_balance_manual, effective_at: employee_time_off_policy.effective_at,
      time_off_category: time_off_category, employee: employee,
      resource_amount: 0, manual_amount: 0)
  end
  let!(:time_off) do
    create(:time_off, time_off_category_id: time_off_category.id, employee: employee)
  end

  describe 'GET #show' do
    subject { get :show, id: id }

    context 'with valid id' do
      let(:id) { time_off.id }

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(
          [:id, :type, :start_time, :end_time, :employee, :time_off_category, :employee_balance]
        ) }
      end
    end

    context 'with invalid id' do
      context 'time off with given id does not exist' do
        let(:id) { 'abc' }

        it { is_expected.to have_http_status(404) }
      end

      context 'time off belongs to other account' do
        before { Account.current = create(:account) }
        let(:id) { time_off.id }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'GET #index' do
    let(:params) {{ time_off_category_id: time_off_category.id }}
    let!(:time_offs) { create_list(:time_off, 3, time_off_category: time_off_category) }
    subject { get :index, params }

    before { user.employee = employee }

    context 'when user is a manager' do
      before { user.update_attribute(:role, 'account_administrator') }
      it 'should return all time off category time offs' do
        subject

        time_off_category.time_offs.each do |time_off|
          expect(response.body).to include time_off[:id]
        end
        expect(response.body).to include time_off.id
      end

      it { is_expected.to have_http_status(200) }
    end

    context 'when the user is not a manager' do
      before { user.role = 'user' }
      context 'when user has an employee' do
        it 'should return employee time offs and not others time offs' do
          subject

          expect(response.body).to include time_off.id

          time_offs.each do |time_off|
            expect(response.body).to_not include time_off[:id]
          end
        end
      end

      context 'when the user does not has an employee' do
        before(:each) do
          user.employee = nil
        end

        it 'should return an empty collection' do
          subject

          time_offs.each do |time_off|
            expect(response.body).to_not include time_off[:id]
          end
          expect(response.body).to_not include time_off.id
        end
      end

      it { is_expected.to have_http_status(200) }
    end

    context 'when user does not have a an employee'
    it 'should not be visible in context of other account' do
      Account.current = create(:account)
      subject

      time_off_category.time_offs.each do |time_off|
        expect(response.body).to_not include time_off[:id]
      end
    end
  end

  describe 'POST #create' do
    before { Employee::Balance.where.not(id: assignation_balance.id).destroy_all }
    let(:time_off) { nil }
    let(:start_time) { '2016-12-30T13:00:00'  }
    let(:end_time) { '2017-1-3T15:00:00' }
    let(:employee_id) { employee.id }
    let(:time_off_category_id) { time_off_category.id }
    let(:params) do
      {
        type: 'time_off',
        start_time: start_time,
        end_time: end_time,
        employee: {
          type: 'employee',
          id: employee_id
        },
        time_off_category: {
          type: 'time_off_category',
          id: time_off_category_id
        }
      }
    end
    subject { post :create, params }

    shared_examples 'Invalid Data' do
      it { expect { subject }.to_not change { TimeOff.count } }
      it { expect { subject }.to_not change { employee.reload.time_offs.count } }
      it { expect { subject }.to_not change { time_off_category.reload.time_offs } }
      it { expect { subject }.to_not change { Employee::Balance.count } }
    end

    context 'with valid params' do
      it { expect { subject }.to change { TimeOff.count }.by(1) }
      it { expect { subject }.to change { Employee::Balance.count }.by(1) }
      it { expect { subject }.to change { time_off_category.reload.time_offs.count }.by(1) }
      it { expect { subject }.to change { employee.reload.time_offs.count }.by(1) }

      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it { expect_json_keys([:id, :type, :employee, :time_off_category, :start_time, :end_time]) }
      end

      context 'with manual_amount' do
        let(:params_with_manual_amount) { params.merge!(manual_amount: 200) }
        subject(:create_with_manual_amount) { post :create, params_with_manual_amount }

        it { expect { create_with_manual_amount }.to change { TimeOff.count }.by(1) }
        it { expect { create_with_manual_amount }.to change { Employee::Balance.count }.by(1) }

        it 'properly assigns manual_amount' do
          create_with_manual_amount
          expect(Employee::Balance.order(:effective_at).last.manual_amount).to eq(200)
        end
      end

      context 'when time off has time entries in its period' do
        let(:first_day) { create(:presence_day, order: 5, presence_policy: policy) }
        let(:second_day) { create(:presence_day, order: 2, presence_policy: policy) }
        let!(:second_entry) { create(:time_entry, presence_day: second_day) }
        let!(:first_entry) do
          create(:time_entry, start_time: '10:00', end_time: '17:00', presence_day: first_day)
        end

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to change { TimeOff.count }.by(1) }

        it { is_expected.to have_http_status(201) }

        context 'new employee balance amount' do
          before do
            create(:presence_day, order: 7, presence_policy: policy)
            EmployeePresencePolicy.first.update!(order_of_start_day: 5)
            subject
          end

          it { expect(Employee::Balance.order(:effective_at).last.amount).to eq (-240) }
        end

        context 'when they are other balances in time offs period' do
          before do
            employee_time_off_policy.update!(effective_at: Time.now)
            ManageEmployeeBalanceAdditions.new(employee_time_off_policy).call
            Employee::Balance.update_all(being_processed: false)
          end

          let(:day_before_start_balance) { employee.employee_balances.order(:effective_at).third }
          let(:start_day_balance) { employee.employee_balances.order(:effective_at).fourth }

          it { expect { subject }.to change { TimeOff.count }.by(1) }
          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          it { expect { subject }.to change { start_day_balance.reload.being_processed }.to true }
          it do
            expect { subject }.to change { start_day_balance.reload.being_processed }.to true
          end

          it { is_expected.to have_http_status(201) }
        end
      end

      context 'when employee does not have employee presence policy' do
        before { EmployeePresencePolicy.destroy_all }

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to change { TimeOff.count }.by(1) }

        it { is_expected.to have_http_status(201) }

        context 'new employee balance amount' do
          before { subject }

          it { expect(Employee::Balance.last.amount).to eq 0 }
        end
      end

      context 'when time off is created after contract end' do
        before do
          create(:employee_event,
            employee: employee, event_type: 'contract_end',
            effective_at: start_time.to_date - 10.days)
        end

        it { is_expected.to have_http_status(422) }
        it do
          subject

          expect(response.body)
            .to include 'can\'t be set outside of employee contract period'
        end

        context 'and rehired event' do
          before do
            create(:employee_event,
              employee: employee, event_type: 'hired', effective_at: start_time.to_date - 1.day)
          end

          context 'and employee has employee time off policy assigned' do
            before do
              create(:employee_time_off_policy,
                effective_at: start_time.to_date - 1.day, employee: employee,
                time_off_policy: create(:time_off_policy, time_off_category: time_off_category))
            end

            it { is_expected.to have_http_status(201) }
            it { expect { subject }.to change { TimeOff.count }.by(1) }
            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          end

          context 'and employee does not have employee time off policy assigned' do
            it { is_expected.to have_http_status(422) }
            it do
              subject

              expect(response.body).to include 'Time off policy in category required'
            end
          end
        end
      end
    end

    context 'with invalid params' do
      context 'when params are missing' do
        before { params.delete(:start_time) }

        it_behaves_like 'Invalid Data'

        it { is_expected.to have_http_status(422) }
      end

      context 'with params that do not pass validation' do
        let(:end_time) { '2016-10-4T13:00:00' }

        it_behaves_like 'Invalid Data'

        it { is_expected.to have_http_status(422) }
      end

      context 'with invalid id' do
        context 'with invalid employee id' do
          let(:employee_id) { 'abc' }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }
        end

        context 'with employee does not belong to account' do
          before { Account.current = create(:account) }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }
        end

        context 'with invalid category id' do
          let(:time_off_category_id) { 'abc' }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }
        end

        context 'with category does not belong to account' do
          before { Account.current = create(:account) }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }
        end
      end
    end
  end

  describe 'PUT #update' do
    before { Employee::Balance.destroy_all }

    let(:id) { time_off.id }
    let(:start_time) { Date.today }
    let(:end_time) { Date.today + 1.week }
    let(:params) do
      {
        id: id,
        type: 'time_off',
        start_time: start_time,
        end_time: end_time,
      }
    end
    let!(:employee_balance) do
      create(:employee_balance,
        time_off: time_off, time_off_category: time_off_category, employee: employee)
    end

    subject { put :update, params }

    context 'with valid params' do
      it { expect { subject }.to change { time_off.reload.start_time } }
      it { expect { subject }.to change { time_off.reload.end_time } }
      it { expect { subject }.to change { employee_balance.reload.being_processed } }

      it { is_expected.to have_http_status(204) }

      context 'with manual_amount' do
        let(:params_with_manual_amount) { params.merge!(manual_amount: 200) }
        subject(:update_with_manual_amount) { put :update, params_with_manual_amount }

        before do
          ActiveJob::Base.queue_adapter = :inline
          update_with_manual_amount
        end

        after { ActiveJob::Base.queue_adapter = :sidekiq }

        it do
          expect(employee_balance.reload.manual_amount).to eq(200)
        end
      end

      context 'when there are balances between time offs start and end time' do
        before do
          time_off.update!(start_time: Date.new(2017, 1, 1))
          policy.presence_days.first.time_entries.create!(start_time: '10:00', end_time: '18:00')
          ManageEmployeeBalanceAdditions.new(employee_time_off_policy).call
          Employee::Balance.update_all(being_processed: false)
        end

        let!(:balance_after_time_off) do
          Employee::Balance
          .where(
            'effective_at BETWEEN ? AND ?', time_off.start_time, time_off.end_time
          )
          .where(time_off_id: nil).first
        end

        context 'and time off moved to future' do
          let(:start_time) { 14.months.since }
          let(:end_time) { 15.months.since }
          let(:balances_after_new_effective_at) do
            employee.employee_balances.order(:effective_at).last(2)
          end

          it do
            expect { subject }.to change { balance_after_time_off.reload.being_processed }.to true
          end
          it do
            expect { subject }
              .to change { balances_after_new_effective_at.first.reload.being_processed }.to true
          end
          it do
            expect { subject }
              .to change { balances_after_new_effective_at.last.reload.being_processed }.to true
          end
        end

        context 'and time off moved to past' do
          let!(:balances_after_new_effective_at) { Employee::Balance.order(:effective_at).first(2) }
          let(:start_time) { 1.year.ago }
          let(:end_time) { 11.months.since }

          it do
            expect { subject }
              .to change { balances_after_new_effective_at.first.reload.being_processed }.to true
          end
          it do
            expect { subject }
              .to change { balances_after_new_effective_at.last.reload.being_processed }.to true
          end
          it do
            expect { subject }.to change { balance_after_time_off.reload.being_processed }.to true
          end
        end
      end

      context 'when time off is created after contract end' do
        before do
          create(:employee_event,
            employee: employee, event_type: 'contract_end',
            effective_at: start_time.to_date - 10.days)
        end

        it { is_expected.to have_http_status(422) }
        it do
          subject

          expect(response.body)
            .to include 'can\'t be set outside of employee contract period'
        end

        context 'and rehired event' do
          before do
            create(:employee_event,
              employee: employee, event_type: 'hired', effective_at: start_time.to_date - 1.day)
          end

          context 'and employee has employee time off policy assigned' do
            before do
              create(:employee_time_off_policy,
                effective_at: start_time.to_date - 1.day, employee: employee,
                time_off_policy: create(:time_off_policy, time_off_category: time_off_category))
            end

            it { is_expected.to have_http_status(204) }
            it { expect { subject }.to change { time_off.reload.start_time } }
            it { expect { subject }.to change { time_off.reload.end_time } }
          end

          context 'and employee does not have employee time off policy assigned' do
            it { is_expected.to have_http_status(422) }
            it do
              subject

              expect(response.body).to include 'Time off policy in category required'
            end
          end
        end
      end
    end

    context 'with invalid params' do
      context 'params are missing' do
        before { params.delete(:start_time) }

        it { expect { subject }.to_not change { time_off.reload.start_time } }
        it { expect { subject }.to_not change { time_off.reload.end_time } }
        it { expect { subject }.to_not change { employee_balance.reload.amount } }

        it { is_expected.to have_http_status(422) }
      end

      context 'params do not pass validation' do
        let(:end_time) { start_time - 1.week }

        it { expect { subject }.to_not change { time_off.reload.start_time } }
        it { expect { subject }.to_not change { time_off.reload.end_time } }
        it { expect { subject }.to_not change { employee_balance.reload.amount } }

        it { is_expected.to have_http_status(422) }
      end

      context 'invalid id given' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { time_off.reload.start_time } }
        it { expect { subject }.to_not change { time_off.reload.end_time } }
        it { expect { subject }.to_not change { employee_balance.reload.amount } }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, id: id }
    let(:id) { time_off.id }

    context 'with valid data' do

      context 'when there are balances to be updated' do
        let(:id) { time_off.id }

        it { expect { subject }.to change { TimeOff.count }.by(-1) }
        it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
        it { is_expected.to have_http_status(204) }
      end

      context 'when there are balances between time off start and end time' do
        before { time_off.update!(start_time: Date.new(2017, 1, 1)) }
        let!(:policy_start_balance) do
          create(:employee_balance_manual,
            effective_at: Date.new(2017, 1, 1), being_processed: false, resource_amount: 1000,
            time_off_category: employee_time_off_policy.time_off_category, employee: employee
          )
        end

        it { expect { subject }.to change { TimeOff.count }.by(-1) }
        it { expect { subject }.to change { policy_start_balance.reload.being_processed }.to true }
        it { expect { subject }.to change { Employee::Balance.count }.by(-1) }

        it { is_expected.to have_http_status(204) }
      end

      context 'when there are no balances to be updated' do
        let(:id) { time_off.id }
        let!(:later_time_off) do
          create(:time_off,
            time_off_category_id: time_off_category.id,
            employee: employee,
            start_time: time_off.end_time + 2.days,
            end_time: time_off.end_time + 7.days,
            )
        end

        it { expect { subject }.to change { TimeOff.count }.by(-1) }
        it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
        it { is_expected.to have_http_status(204) }
      end
    end

    context 'with invalid data' do
      context 'with invalid id' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { TimeOff.count } }
        it { expect { subject }.to_not change { Employee::Balance.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'with not account id' do
        before { Account.current = create(:account) }

        it { expect { subject }.to_not change { TimeOff.count } }
        it { expect { subject }.to_not change { Employee::Balance.count } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end

require 'rails_helper'

RSpec.describe DeleteEvent do
  include_context 'shared_context_timecop_helper'

  before do
    allow_any_instance_of(::Payments::UpdateSubscriptionQuantity)
      .to receive(:perform_now).and_return(true)
  end

  subject { DeleteEvent.new(event).call }
  let!(:employee) { create(:employee) }
  let(:account) { employee.account }
  let(:new_event) do
    create(:employee_event, employee: employee, event_type: event_type, effective_at: effective_at)
  end

  context 'when event has different type than contract end or hired' do
    let(:event_type) { 'child_death' }
    let(:effective_at) { Date.today }
    let!(:event) { new_event }

    it { expect { subject }.to change { Employee::Event.count }.by(-1) }
  end

  context 'event with etop and epp' do
    let(:effective_at) { 2.years.ago }
    let!(:employee_time_off_policy) do
      create(:employee_time_off_policy, employee: employee, effective_at: effective_at)
    end
    let!(:employee_presence_policy) do
      create(:employee_presence_policy, employee: employee, effective_at: effective_at)
    end

    let!(:event) do
      create(:employee_event,
             employee: employee, event_type: 'work_contract', effective_at: effective_at,
             employee_presence_policy: employee_presence_policy,
             employee_time_off_policy: employee_time_off_policy)
    end

    it { expect { subject }.to change{ Employee::Event.count }.by(-1) }
    it { expect { subject }.to change{ EmployeePresencePolicy.count }.by(-1) }
    it { expect { subject }.to change{ EmployeeTimeOffPolicy.count }.by(-1) }
  end

  context 'when event has event type hired or contract end' do
    context 'when event has event type hired' do
      context 'and this is only hired event' do
        let(:event) { employee.events.first }

        context 'when employee does not have join tables assigned' do
          it { expect { subject }.to change { Employee::Event.count }.by(-1) }
          it { expect { subject }.to change { Employee.count }.by(-1) }
        end

        context 'when employee has join tables assigned' do
          before { create(:employee_presence_policy, employee: employee, effective_at: Date.today) }

          it { expect { subject }.to raise_error(ActiveRecord::RecordNotDestroyed) }
        end
      end

      context 'and employee has other hire events' do
        before do
          create(:employee_event,
            event_type: 'contract_end', effective_at: 1.year.ago, employee: employee)
        end
        let!(:event) { new_event }
        let(:event_type) { 'hired' }
        let(:effective_at) { Date.today }

        it { expect { subject }.to change { Employee::Event.count }.by(-1) }
        it { expect { subject }.to_not change { Employee.count } }

        context 'when employee has join tables assigned' do
          before do
            create(:employee_presence_policy, employee: employee, effective_at: effective_at)
          end

          it { expect { subject }.to raise_error(ActiveRecord::RecordNotDestroyed) }
        end
      end
    end

    context 'when event has event type contract end' do
      let(:event_type) { 'contract_end' }
      let(:effective_at) { Date.today }

      context 'and employee does not have join tables assigned' do
        let!(:event) { new_event }

        context 'and there is no hired event after' do
          it { expect { subject }.to change { Employee::Event.count }.by(-1) }

          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
          it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
          it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
        end

        context 'and there is hired event after' do
          before do
            create(:employee_event,
              employee: employee, event_type: 'hired', effective_at: 1.year.since)
          end

          it { expect { subject }.to raise_error(ActiveRecord::RecordNotDestroyed) }
        end
      end

      context 'and employee has join tables assigned' do
        before do
          options = { employee: employee, effective_at: 1.year.ago }
          policy = create(:time_off_policy, :with_end_date,
            time_off_category: create(:time_off_category, account: account))
          create(:employee_time_off_policy, options.merge(time_off_policy: policy))
          create(:employee_presence_policy, options)
          create(:employee_working_place, options)
          new_event
          EmployeeTimeOffPolicy.not_reset.map do |etop|
            ManageEmployeeBalanceAdditions.new(etop).call
          end
        end

        let!(:event) { new_event }

        context 'and no hired event after' do
          let!(:balance_to_update) do
            Employee::Balance.where(
              validity_date: new_event.effective_at + 1.day + Employee::Balance::RESET_OFFSET
            )
          end

          it { expect { subject }.to change { Employee::Event.count }.by(-1) }
          it { expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.by(-1) }
          it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(-1) }
          it { expect { subject }.to change { EmployeeTimeOffPolicy.with_reset.count }.by(-1) }
          it do
            expect { subject }
              .to change { Employee::Balance.where.not(balance_type: 'reset').count }
          end
          it do
            expect { subject }
              .to change { Employee::Balance.where(balance_type: 'reset').count }.by(-1)
          end

          it { expect { subject }.to_not change { Employee.count } }
          it do
            expect { subject }.to change { balance_to_update.reload.pluck(:being_processed).uniq }
          end
        end

        context 'and hired event after' do
          before do
            create(:employee_event,
              employee: employee, effective_at: 1.year.since, event_type: 'hired')
          end

          it { expect { subject }.to raise_error(ActiveRecord::RecordNotDestroyed) }
        end
      end
    end
  end
end

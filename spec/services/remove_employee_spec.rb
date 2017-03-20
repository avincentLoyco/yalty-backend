require 'rails_helper'

RSpec.describe RemoveEmployee, type: :service do
  include_context 'shared_context_timecop_helper'

  let!(:user) { create(:account_user) }
  let!(:employee) { create(:employee, account_user_id: user.id) }
  let!(:rwt) { create(:registered_working_time, employee: employee) }
  let!(:other_event) do
    create(:employee_event, employee: employee, effective_at: employee.hired_date - 1.month)
  end

  subject(:call_service) { described_class.new(employee).call }

  context 'employee still have hired event' do
    it 'checks if employee have hired events' do
      expect(employee).to receive(:hired_events?).and_return(true)
      call_service
    end

    it { expect { call_service }.to_not change { employee.registered_working_times.count } }
    it { expect { call_service }.to_not change { employee.events.count } }
    it { expect { call_service }.to_not change { Employee.count } }
    it { expect { call_service }.to_not change { Account::User.count } }
  end

  context 'employee have no hired events left' do
    before { employee.events.where(event_type: 'hired').last.destroy! }

    it 'checks if employee have hired events' do
      expect(employee).to receive(:hired_events?).and_return(false)
      call_service
    end

    it { expect { call_service }.to change { employee.registered_working_times.count } }
    it { expect { call_service }.to change { employee.events.count }.by(-1) }
    it { expect { call_service }.to change { Employee.count }.by(-1) }
    it { expect { call_service }.to change { Account::User.count }.by(-1) }
  end
end

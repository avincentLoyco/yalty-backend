require 'rails_helper'
require 'rake'

RSpec.describe 'create_balances_for_time_offs', type: :rake do
  include_context 'shared_context_account_helper'

  before { allow_any_instance_of(TimeOff).to receive(:valid?) { true } }
  let!(:account) { create(:account) }
  let!(:category) { create(:time_off_category, account: account, name: 'vacancy') }
  let!(:employee) { create(:employee, account: account) }

  context 'it should create balances for time offs which do not have ones' do
    before do
      first_without_balance.employee_balance = nil
      second_without_balance.employee_balance = nil
    end
    let!(:first_without_balance) do
      create(:time_off,
        time_off_category: category, employee: employee,start_time: Time.now - 2.days
      )
    end
    let!(:second_without_balance) do
      create(:time_off,
        time_off_category: category, employee: employee, start_time: Time.now - 1.week
      )
    end

    context 'for balances in the same category' do
      it { expect { subject.execute }.to change { Employee::Balance.count }.by(2) }
      it { expect { subject.execute }.to change { EmployeeTimeOffPolicy.count }.by(1) }
      it { expect { subject.execute }.to change { TimeOffPolicy.count }.by(1) }
    end

    context 'for balances in different categories' do
      let(:new_category) { create(:time_off_category, account: account) }
      before { second_without_balance.update!(time_off_category: new_category) }

      it { expect { subject.execute }.to change { Employee::Balance.count }.by(2) }
      it { expect { subject.execute }.to change { EmployeeTimeOffPolicy.count }.by(2) }
      it { expect { subject.execute }.to change { TimeOffPolicy.count }.by(2) }
    end
  end

  context 'it should not create balance when time off has one' do
    let!(:time_offs_with_balance) { create_list(:time_off, 2) }

    it { expect { subject.execute }.to_not change { Employee::Balance.count } }
  end
end

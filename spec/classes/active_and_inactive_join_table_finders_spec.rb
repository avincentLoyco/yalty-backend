require 'rails_helper'

RSpec.describe ActiveAndInactiveJoinTableFinders do
  include_context 'shared_context_account_helper'

  let(:account) { create(:account) }
  let!(:employee) { create(:employee, account: account) }

  shared_examples 'Without join tables assigned' do
    subject do
      ActiveAndInactiveJoinTableFinders
        .new(resource_class, join_table_class, account.id)
        .without_join_tables_assigned
    end

    it { expect(subject).to include resources.first.id }
    it { expect(subject).to include resources.second.id }

    it { expect(subject).to_not include resources.third.id }
    it { expect(subject).to_not include resources.last.id }
  end

  shared_examples 'Assigned ids' do
    subject do
      ActiveAndInactiveJoinTableFinders
        .new(resource_class, join_table_class, account.id)
        .assigned_ids
    end

    it { expect(subject).to include resources.last.id }

    it { expect(subject).to_not include resources.first.id }
    it { expect(subject).to_not include resources.second.id }
    it { expect(subject).to_not include resources.third.id }
  end

  context 'PresencePolicy' do
    before do
      create(:employee_presence_policy,
        employee: employee, presence_policy: resources.third, effective_at: Time.now - 1.year)
      create(:employee_presence_policy,
        employee: employee, presence_policy: resources.last, effective_at: Time.now - 1.day)
    end

    let(:resource_class) { PresencePolicy }
    let(:join_table_class) { EmployeePresencePolicy }
    let(:resources) { create_list(:presence_policy, 4, :with_presence_day, account: account) }

    it_behaves_like 'Without join tables assigned'
    it_behaves_like 'Assigned ids'
  end

  context 'WorkingPlace' do
    before do
      employee.first_employee_working_place.update!(working_place: resources.third)
      create(:employee_working_place,
        employee: employee, working_place: resources.last, effective_at: Time.now - 1.day)
    end

    let(:resource_class) { WorkingPlace }
    let(:join_table_class) { EmployeeWorkingPlace }
    let(:resources) { create_list(:working_place, 4, account: account) }

    it_behaves_like 'Without join tables assigned'
    it_behaves_like 'Assigned ids'
  end

  context 'TimeOffPolicy' do
    before do
      create(:employee_time_off_policy,
        employee: employee, time_off_policy: resources.third, effective_at: Time.now - 1.year)
      create(:employee_time_off_policy,
        employee: employee, time_off_policy: resources.last, effective_at: Time.now - 1.day)
    end

    let(:resource_class) { TimeOffPolicy }
    let(:join_table_class) { EmployeeTimeOffPolicy }
    let(:category) { create(:time_off_category, account: account) }
    let(:resources) { create_list(:time_off_policy, 4, time_off_category: category) }

    it_behaves_like 'Without join tables assigned'
    it_behaves_like 'Assigned ids'
  end
end

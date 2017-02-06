FactoryGirl.define do
  factory :employee_event, :class => 'Employee::Event' do
    effective_at { 1.day.ago.at_beginning_of_day }
    event_type 'default'
    comment 'A comment about event'

    after(:build) do |employee_event|
      if employee_event.employee.blank?
        employee_event.event_type = 'hired'
        employee = build(:employee, events: [employee_event])
        employee_event.employee = employee
      end

      employee_event.account = employee_event.employee.account

      if employee_event.event_type.eql?('contract_end')
        employee = employee_event.employee
        hired_date = employee.hired_date_for(employee_event.effective_at)
        account = employee.account
        effective_at = employee_event.effective_at + 1.day

        if employee.employee_presence_policies.not_reset.where('effective_at BETWEEN ? AND ?', hired_date, employee_event.effective_at).any?
          pp = employee.presence_policies.find_by(reset: true) ||
               create(:presence_policy, account: account, reset: true)
          create(:employee_presence_policy, employee: employee, presence_policy: pp,
            effective_at: effective_at)
        end

        if employee.employee_working_places.not_reset.where('effective_at BETWEEN ? AND ?', hired_date, employee_event.effective_at).any?
          wp = employee.working_places.find_by(reset: true) ||
               create(:working_place, account: account, reset: true)
          create(:employee_working_place, employee: employee, working_place: wp,
            effective_at: effective_at)
        end

        employee.employee_time_off_policies.not_reset.where('effective_at BETWEEN ? AND ?', hired_date, employee_event.effective_at).each do |etop|
          top = employee.account.time_off_policies.find_by(reset: true, time_off_category: etop.time_off_category) ||
                create(:time_off_policy, reset: true, time_off_category: etop.time_off_category)
          create(:employee_time_off_policy, employee: employee, time_off_policy: top,
            effective_at: effective_at)
        end
      end
    end

    trait :contract_end do
      event_type 'contract_end'
    end
  end
end

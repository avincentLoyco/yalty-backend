FactoryGirl.define do
  factory :employee_event, :class => "Employee::Event" do
    effective_at { 1.day.ago.at_beginning_of_day }
    event_type "default"

    after(:build) do |employee_event|
      if employee_event.employee.blank?
        employee_event.event_type = "hired"
        employee = build(:employee, events: [employee_event])
        employee_event.employee = employee
      end

      employee_event.account = employee_event.employee.account
    end

    after(:create) do |employee_event|
      if employee_event.event_type.eql?("contract_end")
        employee = employee_event.employee
        hired_date = employee.hired_date_for(employee_event.effective_at)
        account = employee.account
        effective_at = employee_event.effective_at + 1.day

        not_reset_presence_policies = employee.employee_presence_policies.not_reset
        not_reset_time_off_policies = employee.employee_time_off_policies.not_reset
        not_reset_working_places = employee.employee_working_places.not_reset

        if not_reset_presence_policies .where("effective_at BETWEEN ? AND ?", hired_date, employee_event.effective_at).any? &&
          not_reset_presence_policies.find_by(effective_at: effective_at).blank?

          pp = employee.presence_policies.find_by(reset: true) ||
               create(:presence_policy, account: account, reset: true)
          create(:employee_presence_policy, employee: employee, presence_policy: pp,
            effective_at: effective_at)
        end

        if not_reset_working_places.where("effective_at BETWEEN ? AND ?", hired_date, employee_event.effective_at).any? &&
          not_reset_working_places.find_by(effective_at: effective_at).blank?

          wp = employee.working_places.find_by(reset: true) ||
               create(:working_place, account: account, reset: true)
          create(:employee_working_place, employee: employee, working_place: wp,
            effective_at: effective_at)
        end

        not_reset_time_off_policies.where("effective_at BETWEEN ? AND ?", hired_date, employee_event.effective_at).each do |etop|
          next if not_reset_time_off_policies.where(time_off_category_id: etop.time_off_category_id, effective_at: effective_at).present?
          top = employee.account.time_off_policies.find_by(reset: true, time_off_category: etop.time_off_category) ||
                create(:time_off_policy, reset: true, time_off_category: etop.time_off_category)
          create(:employee_time_off_policy, :with_reset_balance, employee: employee, time_off_policy: top,
            effective_at: effective_at)
        end
      end
    end

    trait :contract_end do
      event_type "contract_end"
    end
  end
end

FactoryGirl.define do
  factory :employee_working_place do
    effective_at { Date.today }

    after(:build) do |employee_working_place|
      if employee_working_place.employee.blank?
        event = build(:employee_event, effective_at: employee_working_place.effective_at)
        build(:employee, employee_working_places: [employee_working_place], events: [event])
      end

      if employee_working_place.working_place.blank?
        working_place = create(:working_place, account: employee_working_place.employee.account)

        employee_working_place.working_place = working_place
      end

      reset_working_place =
        employee_working_place.employee
          .employee_working_places
          .with_reset
          .find_by(effective_at: employee_working_place.effective_at)
      reset_working_place.destroy if reset_working_place.present?
    end
  end
end

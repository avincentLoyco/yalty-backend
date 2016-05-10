FactoryGirl.define do
  factory :employee_working_place do
    effective_at { Faker::Date.between(2.days.ago, Date.today) }

    after(:build) do |employee_working_place|
      if employee_working_place.employee.blank?
        build(:employee, employee_working_places: [employee_working_place])
      end
      working_place = create(:working_place, account: employee_working_place.employee.account)

      employee_working_place.working_place = working_place
    end
  end
end

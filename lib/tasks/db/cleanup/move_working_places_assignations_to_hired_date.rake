namespace :db do
  namespace :cleanup do
    desc "Move employee working places which effective at is before hired date"
    task move_working_places_assignations_to_hired_date: [:environment] do
      Employee.find_each do |employee|
        first_ewp = employee.employee_working_places.order(:effective_at).first
        ewp_at_new_hired_date =
          employee.employee_working_places.find_by(effective_at: employee.hired_date)
        next unless first_ewp.present? &&
            first_ewp.effective_at.to_date < employee.hired_date &&
            !ewp_at_new_hired_date.present?
        params = { employee_id: employee.id, effective_at: employee.hired_date }
        CreateOrUpdateJoinTable.new(EmployeeWorkingPlace, WorkingPlace, params, first_ewp).call
      end
    end
  end
end

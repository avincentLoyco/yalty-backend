class RemoveEmployee
  def initialize(employee)
    @employee = employee
  end

  def call
    return if @employee.events.hired.present?

    Employee.transaction do
      @employee.events.destroy_all
      @employee.registered_working_times.destroy_all
      @employee.destroy!
      @employee.user&.destroy!
    end
  end
end

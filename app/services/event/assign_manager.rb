class AssignManager
  method_object [:employee!, :manager_id!]

  def call
    employee.manager = manager
  end

  private

  def manager
    return if manager_id.blank?
    @manager ||= employee.account.managers.find_by!(id: manager_id)
  end
end

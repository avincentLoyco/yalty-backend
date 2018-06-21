class AbilityUser < Ability
  def initialize(user)
    can :show, PresencePolicy, id: user.employee.presence_policies.pluck(:id)
    can :read, Employee::AttributeDefinition
    can :read, WorkingPlace
    can [:read, :update], Employee, account_user_id: user.id
    can [:update, :read, :index], Account::User, id: user.id
    can [:show, :create, :update], TimeOff, employee_id: user.employee.try(:id)
    can [:read], Account, id: user.account_id
    can [:show], Employee::Balance, employee_id: user.employee.try(:id)
    can %i(create update), Employee::Event, employee_id: user.employee&.id
    cannot %i(create update), Employee::Event, event_type: Employee::Event::MANAGER_EVENTS
    can [:show], Employee::Event, account: { id: user.account_id }
    can :index, Employee::Event do |event, employee_id|
      employee_id.present? && event.account.id == user.account.id
    end
    can :schedule_for_employee, Employee, id: user.employee.try(:id)
    can [:create], RegisteredWorkingTime, employee_id: user.employee.try(:id)
    can :create, :tokens do |_, file_id, attribute_version|
      (file_id.nil? && attribute_version.nil?) ||
        (attribute_version.present? && attribute_version.attribute_name == "profile_picture") ||
        (user.employee.present? && user.employee.file_with?(file_id))
    end
  end
end

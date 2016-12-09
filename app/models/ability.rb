class Ability
  include CanCan::Ability

  def initialize(user)
    if user.account_manager
      can :manage, :all
    else
      can :read, Employee::AttributeDefinition
      can :read, WorkingPlace
      can [:show, :index], Employee
      can :update, Employee, account_user_id: user.id
      can [:update, :read, :index], Account::User, id: user.id
      can [:show, :create, :update], TimeOff do |time_off|
        time_off.employee_id == user.employee.try(:id)
      end
      can [:read], Account, id: user.account_id
      can [:show], Employee::Balance do |employee_balance|
        employee_balance.employee_id == user.employee.try(:id)
      end
      can [:read, :show, :update], Employee::Event do |event|
        event.employee_id == user.employee.try(:id)
      end
      can :schedule_for_employee, Employee, id: user.employee.try(:id)
      can [:create], RegisteredWorkingTime do |registered_working_time|
        registered_working_time.employee_id == user.employee.try(:id)
      end
      can :create, :tokens do |_, file_id, attribute_version|
        (file_id.nil? && attribute_version.nil?) ||
          (attribute_version.present? && attribute_version.attribute_name == 'profile_picture') ||
          (user.employee.present? && user.employee.has_file_with?(file_id))
      end
    end
  end
end

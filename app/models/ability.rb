class Ability
  include CanCan::Ability

  def initialize(user)
    if user.role.eql?("account_owner")
      can :manage, :all
      cannot :manage, :available_modules
      companyevent_management(user)
    elsif user.role.eql?("yalty")
      can :manage, :all
      cannot :manage, :payments
      companyevent_management(user)
    elsif user.role.eql?("account_administrator")
      can :manage, :all
      cannot :manage, :payments
      cannot :manage, :available_modules
      companyevent_management(user)
    elsif user.role.eql?("user")
      cannot :read, CompanyEvent
      can :show, PresencePolicy do |presence_policy|
        EmployeePresencePolicy
          .where(employee_id: user.employee.id)
          .pluck(:presence_policy_id)
          .include?(presence_policy.id)
      end
      can :read, Employee::AttributeDefinition
      can :read, WorkingPlace
      can [:read, :update], Employee, account_user_id: user.id
      can [:update, :read, :index], Account::User, id: user.id
      can [:show, :create, :update], TimeOff, employee_id: user.employee.try(:id)
      can [:decline, :approve], TimeOff do |time_off|
        time_off.employee.manager_id == user.id
      end
      can [:read], Account, id: user.account_id
      can [:show], Employee::Balance do |employee_balance|
        employee_balance.employee_id == user.employee.try(:id)
      end
      can %i(create update), Employee::Event, employee_id: user.employee&.id
      cannot %i(create update), Employee::Event, event_type: Employee::Event::MANAGER_EVENTS
      can [:show], Employee::Event do |event|
        event.account.id == user.account.id
      end
      can :index, Employee::Event do |event, employee_id|
        employee_id.present? && event.account.id == user.account.id
      end
      can :schedule_for_employee, Employee, id: user.employee.try(:id)
      can [:create], RegisteredWorkingTime do |registered_working_time|
        registered_working_time.employee_id == user.employee.try(:id)
      end
      can :create, :tokens do |_, file_id, attribute_version|
        (file_id.nil? && attribute_version.nil?) ||
          (attribute_version.present? && attribute_version.attribute_name == "profile_picture") ||
          (user.employee.present? && user.employee.file_with?(file_id))
      end
    end
  end

  private

  def companyevent_management(user)
    return if user.account.available_modules.include?("companyevent")
    cannot [:create, :update, :destroy], CompanyEvent
  end
end

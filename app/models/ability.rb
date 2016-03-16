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
        time_off.employee_id = user.employee.try(:id)
      end
      can [:read], Account, id: user.account_id
      can [:read, :show, :update], Employee::Event do |event|
        event.employee_id = user.employee.try(:id)
      end
    end
  end
end

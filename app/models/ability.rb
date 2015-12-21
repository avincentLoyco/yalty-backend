class Ability
  include CanCan::Ability

  def initialize(user)
    if user.account_manager
      can :manage, :all
    else
    end
  end
end

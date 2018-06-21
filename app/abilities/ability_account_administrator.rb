class AbilityAccountAdministrator < Ability
  def initialize(user)
    can :manage, :all
    cannot :manage, :available_modules
    cannot :manage, :payments
    merge CompanyEventAbility.new(user)
  end
end

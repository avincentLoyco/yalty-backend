class AbilityAccountOwner < Ability
  def initialize(user)
    can :manage, :all
    cannot :manage, :available_modules
    merge CompanyEventAbility.new(user)
  end
end

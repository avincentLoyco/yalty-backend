class YaltyAbility < Ability
  def initialize(user)
    can :manage, :all
    cannot :manage, :payments
    merge CompanyEventAbility.new(user)
  end
end

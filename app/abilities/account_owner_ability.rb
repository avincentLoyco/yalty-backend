class AccountOwnerAbility < Ability
  def initialize(user)
    can :manage, :all
    cannot :manage, :available_modules
    cannot :destroy, Employee, user: { role: "account_owner" }
    merge CompanyEventAbility.new(user)
  end
end

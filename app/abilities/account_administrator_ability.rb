class AccountAdministratorAbility < Ability
  def initialize(user)
    can :manage, :all
    cannot :manage, :available_modules
    cannot :manage, :payments
    cannot :destroy, Employee, user: { role: %w(account_owner account_administrator) }
    merge CompanyEventAbility.new(user)
  end
end

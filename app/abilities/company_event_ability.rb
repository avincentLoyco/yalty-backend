class CompanyEventAbility < Ability
  def initialize(user)
    return if user.account.available_modules.include?("companyevent")
    cannot [:create, :update, :destroy], CompanyEvent
  end
end

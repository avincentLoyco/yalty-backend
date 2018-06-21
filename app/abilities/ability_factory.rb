class AbilityFactory
  static_facade :build_for, :user

  UnknownRoleError = Class.new(StandardError)

  def build_for
    return Ability.new if user.nil?
    verify_role

    ability_class.new(user)
  end

  private

  def verify_role
    return if user.role.in? %w(user yalty account_administrator account_owner)
    raise(UnknownRoleError, "Unknown role passed through: #{user.role}")
  end

  def ability_class
    "ability_#{user.role}".classify.constantize
  end
end

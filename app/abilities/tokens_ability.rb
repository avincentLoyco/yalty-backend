class TokensAbility < Ability
  def initialize(user)
    can :create, :tokens do |_, file_id, attribute_version|
      (file_id.nil? && attribute_version.nil?) ||
        (attribute_version.present? && attribute_version.attribute_name == "profile_picture") ||
        (user.employee.present? && user.employee.file_with?(file_id))
    end
  end
end

module UserSettingsRules
  include BaseRules

  def put_rules
    Gate.rules do
      required :email
      optional :password_params do
        required :old_password
        required :password
        required :password_confirmation
      end
    end
  end
end

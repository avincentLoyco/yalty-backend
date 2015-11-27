module UserPasswordRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :email, :String
    end
  end

  def put_rules
    Gate.rules do
      required :reset_password_token, :String
      required :password, :String
      required :password_confirmation, :String
    end
  end
end

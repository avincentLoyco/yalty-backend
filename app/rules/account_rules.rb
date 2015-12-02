module AccountRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :account do
        required :company_name
      end
      required :user do
        required :password
        required :email
      end
      required :registration_key do
        required :token
      end
    end
  end

  def get_rules
    Gate.rules do
      required :email
    end
  end
end

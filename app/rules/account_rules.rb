module AccountRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :account do
        required :company_name
        optional :default_locale, :String, allow_nil: true
      end
      required :user do
        optional :password, :String, allow_nil: true
        required :email
      end
    end
  end

  def get_rules
    Gate.rules do
      required :email
    end
  end
end

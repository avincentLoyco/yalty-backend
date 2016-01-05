module UserRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :email, :String
      optional :password, :String
      optional :account_manager, :Boolean
      optional :employee, allow_nil: true do
        required :id
      end
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      optional :email, :String
      optional :password, :String
      optional :account_manager, :Boolean
      optional :employee, allow_nil: true do
        required :id
      end
    end
  end
end

module TimeOffCategoriesRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :name
      required :system
    end
  end

  def put_rules
    Gate.rules do
      required :name
      required :system
    end
  end
end

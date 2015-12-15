module TimeOffCategoriesRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :name
    end
  end

  def put_rules
    Gate.rules do
      required :name
    end
  end
end

module NewsletterRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :email
      required :name
      optional :language, :String
    end
  end
end

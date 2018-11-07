# TODO: This logic should be moved to a repository in future refactor

module TimeOffCategories
  class FindByName
    include AppDependencies[
      account_model: "models.account",
    ]

    def call(name)
      account_model
        .current
        .time_off_categories
        .find_by(name: name)
    end
  end
end

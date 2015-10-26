module V1
  class PresencePolicyRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name
      }
      .merge(basic)
    end
  end
end

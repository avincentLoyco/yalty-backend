module Api::V1
  class TimeOffCategoryRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name,
        system: resource.system
      }
        .merge(basic)
    end
  end
end

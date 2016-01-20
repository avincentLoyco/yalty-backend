module Api::V1
  class TimeOffPolicyRepresenter < BaseRepresenter
    def complete
      {

      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      {
        
      }
    end
  end
end

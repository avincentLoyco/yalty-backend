module Api::V1
  class UserSettingsRepresenter < BaseRepresenter
    def complete
      {
        email: resource.email
      }.merge(basic)
    end
  end
end

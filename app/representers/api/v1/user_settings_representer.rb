module Api::V1
  class UserSettingsRepresenter < BaseRepresenter
    def complete
      {
        email: resource.email,
        locale: resource.locale
      }.merge(basic)
    end
  end
end

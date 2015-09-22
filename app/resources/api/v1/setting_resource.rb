module API
  module V1
    class SettingResource < JSONAPI::Resource
      model_name 'Account'
      attributes :subdomain, :name, :timezone, :default_locale

      def name
        @model.company_name
      end

      def self.records(options = {})
        Account.where(id: Account.current.id)
      end
    end
  end
end

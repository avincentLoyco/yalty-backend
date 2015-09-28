Rails.application.routes.draw do
  # API
  namespace :api, path: 'api', constraints: { subdomain: /^api/ } do
    namespace :v1 do
      jsonapi_resources :employees do
        jsonapi_relationships
      end
      jsonapi_resources :employee_attributes
      jsonapi_resources :employee_events
      jsonapi_resources :employee_attribute_definitions
      jsonapi_resources :working_places do
        jsonapi_relationships
      end
      jsonapi_resource :settings, only: [:show, :update]
      jsonapi_resources :holiday_policies do
        jsonapi_relationships
        jsonapi_resources :holidays
      end
    end
  end

  # LAUNCHPAD
  constraints subdomain: /^launchpad/ do
    scope 'oauth' do
      use_doorkeeper scope: ''

      with_options as: nil do
        post 'accounts',       to: 'auth/accounts#create'
        get  'accounts/token', to: 'auth/accounts/tokens#create'
      end
    end
  end
end

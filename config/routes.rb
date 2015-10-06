Rails.application.routes.draw do
  # API
  namespace :api, path: 'api', constraints: { subdomain: /^api/ } do
    namespace :v1 do
      resources :working_places, only: [:show, :index, :create, :update, :destroy]

      jsonapi_resources :employees do
        jsonapi_relationships
        jsonapi_related_resource :holiday_policy
      end
      jsonapi_resources :employee_attributes
      jsonapi_resources :employee_events
      jsonapi_resources :employee_attribute_definitions
      jsonapi_resource :settings, only: [:show, :update] do
        collection do
          put :'assign-holiday-policy'
        end
      end
      jsonapi_resources :holiday_policies do
        jsonapi_relationships
      end

      jsonapi_resources :holidays
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

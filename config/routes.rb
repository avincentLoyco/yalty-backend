Rails.application.routes.draw do
  # API
  namespace :api, path: 'api', constraints: { subdomain: /^api/ } do
    namespace :v1 do
      resources :working_places, except: [:edit, :new]
      resources :holiday_policies, except: [:edit, :new]
      resources :holidays, except: [:edit, :new]
      resource :settings, only: [:show, :update]
      resources :employee_attribute_definitions

      jsonapi_resources :employees do
        jsonapi_relationships
      end
      jsonapi_resources :employee_attributes
      jsonapi_resources :employee_events
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

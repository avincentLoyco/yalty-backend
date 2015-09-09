Rails.application.routes.draw do
  # API
  namespace :api, path: 'api', constraints: { subdomain: 'api' } do
    namespace :v1 do
      namespace :employees do
        jsonapi_resources :attribute_definitions
        jsonapi_resources :events
      end
      jsonapi_resources :employees do
        jsonapi_relationships
      end
    end
  end

  # LAUNCHPAD
  constraints subdomain: 'launchpad' do
    scope 'oauth' do
      use_doorkeeper scope: ''

      with_options as: nil do
        post 'accounts',       to: 'auth/accounts#create'
        get  'accounts/token', to: 'auth/accounts/tokens#create'
      end
    end
  end
end

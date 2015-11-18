Rails.application.routes.draw do
  # API
  namespace :api, path: '', constraints: { subdomain: /^api/ } do
    namespace :v1 do
      resources :working_places, except: [:edit, :new]
      resources :holiday_policies, except: [:edit, :new] do
        resources :holidays, only: :index
      end
      resources :holidays, except: [:edit, :new, :index]
      resource :settings, only: [:show, :update] do
        collection do
          get :public_show
        end
      end
      resources :employee_attribute_definitions
      resources :employees, only: [:index, :show, :update] do
        resources :employee_events, only: :index
      end
      resources :employee_events, only: [:show, :create, :update]
      resources :presence_policies, except: [:edit, :new]
      resources :presence_days, except: [:edit, :new]
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

  # Catch all invalid routings
  match "*path", :to => "errors#routing_error", via: :all
end

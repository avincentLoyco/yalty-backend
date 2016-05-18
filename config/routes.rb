Rails.application.routes.draw do
  # ping
  get 'ping', to: lambda {|env| [200, {'Content-Type' => 'text/plain'}, ['PONG']] }

  # API
  namespace :api, path: '', constraints: { subdomain: /^api/ } do
    namespace :v1 do
      resources :working_places, except: [:edit, :new]
      resources :holiday_policies, except: [:edit, :new]
      resources :countries, only: [:show]
      resource :settings, only: [:show, :update]
      resources :employee_attribute_definitions
      resources :employees, only: [:index, :show, :update] do
        resources :employee_events, only: :index
        resources :employee_balances, only: :index
      end
      resources :employee_events, only: [:show, :create, :update]
      resources :presence_policies, except: [:edit, :new] do
        resources :presence_days, only: :index
      end
      resources :presence_days, except: [:edit, :new, :index] do
        resources :time_entries, only: :index
      end
      resource :user_settings, only: [:show, :update]
      resources :employee_event_types, only: [:index]
      resources :time_off_categories, except: [:edit, :new] do
        resources :time_offs, only: :index
        resources :time_off_policies, only: :index
      end
      resources :time_offs, except: [:edit, :new, :index]
      resources :time_entries, except: [:edit, :new, :index]
      resources :time_off_policies, except: [:edit, :new]
      resources :users
      resources :employee_balances, except: [:edit, :new]

      get '/employee_event_types/:employee_event_type', to: "employee_event_types#show"
    end
  end

  # LAUNCHPAD
  constraints subdomain: /^launchpad/ do
    scope 'oauth' do
      use_doorkeeper scope: ''

      with_options as: nil do
        post 'accounts',       to: 'auth/accounts#create'
        get  'accounts/token', to: 'auth/accounts/tokens#create'
        post 'accounts/list',  to: 'auth/accounts#list'
        post 'users/password', to: 'auth/users#reset_password'
        put  'users/password', to: 'auth/users#new_password'
      end
    end
  end

  # ADMIN
  constraints subdomain: /^admin/ do
    mount ResqueWeb::Engine => '/resque'
  end

  # Catch all invalid routings
  match "*path", :to => "errors#routing_error", via: :all
end

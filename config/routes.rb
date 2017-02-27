require 'sidekiq/web'

Rails.application.routes.draw do
  # API
  namespace :api, path: '', constraints: { subdomain: /^api/ } do
    namespace :v1 do
      namespace :payments do
        resources 'cards', except: [:show, :update]
        get 'subscription', to: 'subscriptions#index'
      end
      resources :working_places, except: [:edit, :new] do
        post '/employees', to: "employee_working_places#create"
        get '/employees', to: "employee_working_places#index"
      end
      resources :employee_working_places, only: [:update, :destroy]
      resources :employee_time_off_policies, only: [:update, :destroy]
      resources :employee_presence_policies, only: [:update, :destroy]
      resources :holiday_policies, except: [:edit, :new]
      resources :countries, only: [:show]
      resource :settings, only: [:show, :update]
      resources :employee_attribute_definitions
      resources :employees, only: [:index, :show] do
        get 'employee_balance_overview', to: 'employee_balance_overviews#show'
        resources :employee_events, only: :index
        resources :employee_balances, only: :index
        post '/working_times', to: 'registered_working_times#create'
        get '/schedule', to: 'schedules#schedule_for_employee'
        get '/working_places', to: "employee_working_places#index"
        get '/attributes', to: 'employee_attributes#show'
      end
      resources :employee_events, only: [:show, :create, :update]
      resources :presence_policies, except: [:edit, :new] do
        get '/employees', to: 'employee_presence_policies#index'
        post '/employees', to: 'employee_presence_policies#create'
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
      resources :time_off_policies, except: [:edit, :new] do
        post '/employees', to: "employee_time_off_policies#create"
        get '/employees', to: "employee_time_off_policies#index"
      end

      mount FileStorageUploadDownload, at: '/files'

      resources :users
      resources :employee_balances, except: [:edit, :new]
      resources :file_storage_tokens, only: :create

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

    post 'newsletters', to: 'newsletters#create'
    post 'referrals',   to: 'referrals#create'
  end

  # ADMIN
  constraints subdomain: /^admin/ do
    mount Sidekiq::Web => '/sidekiq'
    get 'referrals/referrers', to: 'referrals#referrers_csv', defaults: { format: :csv }
  end

  # Catch all invalid routings
  match "*path", :to => "errors#routing_error", via: :all
end

require 'sidekiq/web'

Rails.application.routes.draw do
  # API
  namespace :api, path: '', constraints: { subdomain: /^api/ } do
    namespace :v1 do
      namespace :payments do
        resources 'cards', except: [:show]
        resources 'plans', only: [:create, :destroy]
        resources 'invoices', only: [:index]
        get 'subscription', to: 'subscriptions#index'
        put 'subscription/settings', to: 'subscriptions#settings'
        post 'webhook', to: 'webhooks#webhook'
      end
      resources :working_places, except: [:edit, :new] do
        post '/employees', to: "employee_working_places#create"
        get '/employees', to: "employee_working_places#index"
      end
      resource :export, only: [:create, :show]
      resource :service_offer, only: [:create]
      resources :available_modules, only: [:index, :update]
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
        post '/working_times', to: 'registered_working_times#create'
        get '/schedule', to: 'schedules#schedule_for_employee'
        get '/working_places', to: "employee_working_places#index"
        get '/attributes', to: 'employee_attributes#show'
      end
      resources :managers, only: [:index, :show]
      get '/employee_balance_overview', to: 'employee_balance_overviews#index'
      get '/employee_events', to: 'employee_events#index'
      resources :employee_events, only: [:show, :create, :update]
      resources :company_events
      resources :employee_events, except: [:index]
      resources :presence_policies, except: [:edit, :new] do
        get '/employees', to: 'employee_presence_policies#index'
        post '/employees', to: 'employee_presence_policies#create'
        resources :presence_days, only: :index
      end
      resources :presence_days, except: [:edit, :new, :index] do
        resources :time_entries, only: :index
      end
      resources :employee_event_types, only: [:index]
      resources :time_off_categories, except: [:edit, :new] do
        resources :time_offs, only: :index
        resources :time_off_policies, only: :index
      end
      resources :weekly_reports, only: [:index]
      resources :time_offs, except: [:edit, :new, :index] do
        scope module: "time_offs" do
          put "/approve", to: "status#approve"
          put "/decline", to: "status#decline"
        end
      end
      resources :time_entries, except: [:edit, :new, :index]
      resources :time_off_policies, except: [:edit, :new] do
        post '/employees', to: "employee_time_off_policies#create"
        get '/employees', to: "employee_time_off_policies#index"
      end

      mount FileStorageUploadDownload, at: '/files'

      resources :users
      resources :file_storage_tokens, only: :create
      resources :notifications, only: [:index] do
        put :read, to: "notifications#read"
      end

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

  # Mailers preview routes (needs to be specified because of invalid routes catch)
  if %w(development staging).include?(Rails.env)
    get '/rails/mailers' => "rails/mailers#index"
    get '/rails/mailers/*path' => "rails/mailers#preview"
  end

  # Catch all invalid routings
  match "*path", :to => "errors#routing_error", via: :all
end

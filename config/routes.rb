Rails.application.routes.draw do
  resources :accounts, only: :create

  namespace :api, path: '', constraints: { subdomain: 'api' } do
    namespace :v1 do
      # TODO
    end
  end
end

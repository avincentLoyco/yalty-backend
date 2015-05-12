Rails.application.routes.draw do
  # API
  namespace :api, path: '', constraints: { subdomain: 'api' } do
    namespace :v1 do
      # TODO
    end
  end

  # LAUNCHPAD
  constraints subdomain: 'launchpad' do
    use_doorkeeper

    resources :accounts, only: :create
  end
end

Rails.application.routes.draw do
  # API
  namespace :api, path: '', constraints: { subdomain: 'api' } do
    namespace :v1 do
      # TODO
    end
  end

  # LAUNCHPAD
  constraints subdomain: 'launchpad' do
    scope :oauth do
      use_doorkeeper

      with_options as: nil do
        post 'accounts',       to: 'auth/accounts#create'
        get  'accounts/token', to: 'auth/accounts/tokens#create'
      end
    end
  end
end

Rails.application.routes.draw do
  # API
  constraints lambda {|request| request.subdomain.start_with?('api') } do
    namespace :api, path: '' do
      namespace :v1 do
        # TODO
      end
    end
  end

  # LAUNCHPAD
  constraints lambda {|request| request.subdomain.start_with?('launchpad') } do
    scope 'oauth' do
      use_doorkeeper scope: ''

      with_options as: nil do
        post 'accounts',       to: 'auth/accounts#create'
        get  'accounts/token', to: 'auth/accounts/tokens#create'
      end
    end
  end
end

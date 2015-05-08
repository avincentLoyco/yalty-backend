Rails.application.routes.draw do
  namespace :api, path: '', constraints: { subdomain: 'api' } do
    namespace :v1 do
      # TODO
    end
  end
end

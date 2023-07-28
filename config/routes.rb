require 'sidekiq/web'

Rails.application.routes.draw do
  root to: 'pages#landing'

  get 'about', to: 'pages#about', as: :about
  get 'tos', to: 'pages#tos', as: :tos

  get 'badness/:secret', to: 'pages#badness'

  match '404', to: 'pages#not_found', via: :all
  match '422', to: 'pages#unacceptable', via: :all
  match '500', to: 'pages#internal_error', via: :all

  direct :git_head do
    "https://github.com/Gamocosm/Gamocosm/tree/#{Gamocosm::GIT_HEAD}"
  end

  direct :blog do
    'https://gamocosm.com/blog/'
  end

  direct :wiki do |page|
    if page.blank?
      'https://github.com/Gamocosm/Gamocosm/wiki'
    else
      "https://github.com/Gamocosm/Gamocosm/wiki/#{page}"
    end
  end

  direct :issues do
    'https://github.com/Gamocosm/Gamocosm/issues'
  end

  direct :source do
    'https://github.com/Gamocosm/Gamocosm'
  end

  direct :license do
    'https://github.com/Gamocosm/Gamocosm/blob/master/LICENSE'
  end

  direct :cuberite_website do
    'https://cuberite.org'
  end

  direct :gitter_lobby do
    'https://gitter.im/gamocosm/Lobby'
  end

  direct :digital_ocean_control_panel do
    'https://cloud.digitalocean.com'
  end

  direct :digital_ocean_status do
    'https://status.digitalocean.com'
  end

  direct :digital_ocean_api_setup do
    'https://docs.digitalocean.com/reference/api/create-personal-access-token/'
  end

  namespace :digital_ocean do
    resources :droplets, only: [:index, :destroy]

    resources :images, only: [:index, :destroy]

    resources :ssh_keys, only: [:index, :create, :destroy]

    resources :volumes, only: [:index, :destroy]

    resources :snapshots, only: [:index, :destroy]

    delete 'cache', to: '/servers#refresh_digital_ocean_cache', as: :refresh_cache
  end

  get 'servers/new', to: 'servers#new', as: :new_server
  post 'servers/new', to: 'servers#create', as: nil
  resources :servers, only: [:index, :show, :update, :destroy] do
    member do
      get 'confirm_delete'

      post 'start'
      post 'stop'
      post 'reboot'

      post 'pause'
      post 'resume'
      post 'command'
      post 'backup'
      get 'download'

      put 'update_properties'

      post 'add_friend'
      post 'remove_friend'

      post 'autoshutdown_enable'
      post 'autoshutdown_disable'

      delete 'clear_logs'

      scope path: 'api/:key', as: :api, controller: :api do
        get 'status'
        post 'start'
        post 'stop'
        post 'reboot'
        post 'pause'
        post 'resume'
        post 'backup'
        post 'exec'
      end
    end
  end

  resources :volumes, only: [:index, :new, :show, :edit, :create, :update, :destroy] do
    member do
      get 'confirm_delete'
      post 'suspend'
      post 'reload'
    end
  end

  # https://www.rubydoc.info/github/heartcombo/devise/main/ActionDispatch/Routing/Mapper%3Adevise_for
  devise_for :users, controllers: { registrations: :registrations }

  # https://github.com/sidekiq/sidekiq/wiki/Monitoring#rails-http-basic-auth-from-routes
  if Rails.env.production?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      # Protect against timing attacks:
      # - See https://codahale.com/a-lesson-in-timing-attacks/
      # - See https://thisdata.com/blog/timing-attacks-against-string-comparison/
      # - Use & (do not use &&) so that it doesn't short circuit.
      # - Use digests to stop length information leaking (see also ActiveSupport::SecurityUtils.variable_size_secure_compare)
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_USERNAME'])) &
        ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_PASSWORD']))
    end
  end
  mount Sidekiq::Web => '/sidekiq'

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end

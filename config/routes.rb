require 'sidekiq/web'

Rails.application.routes.draw do
  root to: 'pages#landing'

  get '/about', to: 'pages#about', as: :about
  get '/tos', to: 'pages#tos', as: :tos
  get '/demo', to: 'pages#demo', as: :demo

  get '/badness/:secret', to: 'pages#badness'

  match '/404', to: 'pages#not_found', via: :all
  match '/422', to: 'pages#unacceptable', via: :all
  match '/500', to: 'pages#internal_error', via: :all

  match '/blog' => redirect('https://gamocosm.com/blog/'), as: :blog, via: :get

  scope '/digital_ocean' do
    get '/setup', to: 'pages#digital_ocean_setup', as: :digital_ocean_setup

    get 'droplets', to: 'servers#show_digital_ocean_droplets', as: :show_digital_ocean_droplets
    delete 'droplets/:id', to: 'servers#destroy_digital_ocean_droplet', as: :destroy_digital_ocean_droplet
    get 'images', to: 'servers#show_digital_ocean_images', as: :show_digital_ocean_images
    delete 'images/:id', to: 'servers#destroy_digital_ocean_image', as: :destroy_digital_ocean_image
    get 'ssh_keys', to: 'servers#show_digital_ocean_ssh_keys', as: :show_digital_ocean_ssh_keys
    post 'ssh_keys', to: 'servers#add_digital_ocean_ssh_key', as: :add_digital_ocean_ssh_key
    delete 'ssh_keys/:id', to: 'servers#destroy_digital_ocean_ssh_key', as: :destroy_digital_ocean_ssh_key
    get 'volumes', to: 'volumes#show_digital_ocean_volumes', as: :show_digital_ocean_volumes
    delete 'volumes/:id', to: 'volumes#destroy_digital_ocean_volume', as: :destroy_digital_ocean_volume
    get 'snapshots', to: 'volumes#show_digital_ocean_snapshots', as: :show_digital_ocean_snapshots
    delete 'snapshots/:id', to: 'volumes#destroy_digital_ocean_snapshot', as: :destroy_digital_ocean_snapshot
    delete 'cache', to: 'servers#refresh_digital_ocean_cache', as: :refresh_digital_ocean_cache
  end

  # https://github.com/sidekiq/sidekiq/wiki/Monitoring#rails-http-basic-auth-from-routes
  if Rails.env.production?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      # Protect against timing attacks:
      # - See https://codahale.com/a-lesson-in-timing-attacks/
      # - See https://thisdata.com/blog/timing-attacks-against-string-comparison/
      # - Use & (do not use &&) so that it doesn't short circuit.
      # - Use digests to stop length information leaking (see also ActiveSupport::SecurityUtils.variable_size_secure_compare)
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_USERNAME'])) &
        ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_PASSWORD']))
    end
  end
  mount Sidekiq::Web => '/sidekiq'

  devise_for :users, controllers: { registrations: 'registrations' }

  resources :servers, path: '/servers' do
    collection do
      post 'new', to: 'servers#create', as: :create
    end
    member do
      get 'delete'
      get 'start'
      get 'stop'
      get 'pause'
      get 'resume'
      get 'backup'
      get 'download'
      get 'reboot'
      put 'update_properties'
      post 'add_friend'
      post 'remove_friend'
      post 'command'
      get 'autoshutdown_enable'
      get 'autoshutdown_disable'
      get 'clear_logs'
      get 'api/:key/status', to: 'servers#api_status', as: :api_status
      post 'api/:key/start', to: 'servers#api_start', as: :api_start
      post 'api/:key/stop', to: 'servers#api_stop', as: :api_stop
      post 'api/:key/reboot', to: 'servers#api_reboot', as: :api_reboot
      post 'api/:key/pause', to: 'servers#api_pause', as: :api_pause
      post 'api/:key/resume', to: 'servers#api_resume', as: :api_resume
      post 'api/:key/backup', to: 'servers#api_backup', as: :api_backup
      post 'api/:key/exec', to: 'servers#api_exec', as: :api_exec
    end
  end

  resources :volumes do
    member do
      get 'delete'
      get 'suspend'
      get 'reload'
    end
  end

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

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

  match '/wiki' => redirect('https://github.com/Gamocosm/Gamocosm/wiki'), as: :wiki, via: :get
  match '/issues' => redirect('https://github.com/Gamocosm/Gamocosm/issues'), as: :issues, via: :get
  match '/source' => redirect('https://github.com/Gamocosm/Gamocosm'), as: :source, via: :get
  match '/git_head' => redirect("https://github.com/Gamocosm/Gamocosm/tree/#{Gamocosm::GIT_HEAD}"), as: :git_head, via: :get
  match '/license' => redirect('https://github.com/Gamocosm/Gamocosm/blob/master/LICENSE'), as: :license, via: :get
  match '/blog' => redirect('https://gamocosm.com/blog/'), as: :blog, via: :get
  match '/irc' => redirect('https://webchat.esper.net/?channels=gamocosm'), as: :irc, via: :get
  match '/irc_history' => redirect('http://irc.gamocosm.com'), as: :irc_history, via: :get

  scope '/wiki' do
    match '/ftp_ssh' => redirect('https://github.com/Gamocosm/Gamocosm/wiki/FTP-and-SSH'), as: :wiki_ftp_ssh, via: :get
    match '/minecraft_versions' => redirect('https://github.com/Gamocosm/Gamocosm/wiki/Installing-different-versions-of-Minecraft'), as: :wiki_minecraft_versions, via: :get
    match '/server_advanced_tab' => redirect('https://github.com/Gamocosm/Gamocosm/wiki/Server-advanced-tab-documentation'), as: :wiki_server_advanced_tab, via: :get
    match '/server_additional_info' => redirect('https://github.com/Gamocosm/Gamocosm/wiki/Additional-Info-for-Server-Admins'), as: :wiki_server_additional_info, via: :get
    match '/troubleshooting' => redirect('https://github.com/Gamocosm/Gamocosm/wiki/Troubleshooting'), as: :wiki_troubleshooting, via: :get
    match '/custom_minecraft' => redirect('https://github.com/Gamocosm/Gamocosm/wiki/Installing-different-versions-of-Minecraft'), as: :wiki_custom_minecraft, via: :get
    match '/security_privacy' => redirect('https://github.com/Gamocosm/Gamocosm/wiki/Security-and-Privacy'), as: :wiki_security_privacy, via: :get
    match '/volumes' => redirect('https://github.com/Gamocosm/Gamocosm/wiki/Using-Digital-Ocean-Volumes'), as: :wiki_volumes, via: :get
  end

  scope '/digital_ocean' do
    get '/setup', to: 'pages#digital_ocean_setup', as: :digital_ocean_setup

    #match '/index' => redirect('https://www.digitalocean.com/?refcode=f787055e1099'), as: :digital_ocean_index, via: :get
    match '/index' => redirect('https://m.do.co/c/758af342c81e'), as: :digital_ocean_index, via: :get
    match '/index_no_ref' => redirect('https://www.digitalocean.com/'), as: :digital_ocean_index_no_ref, via: :get
    #match '/pricing' => redirect('https://www.digitalocean.com/pricing/?refcode=f787055e1099'), as: :digital_ocean_pricing, via: :get
    match '/pricing' => redirect('https://www.digitalocean.com/pricing/?refcode=758af342c81e'), as: :digital_ocean_pricing, via: :get
    match '/pricing_no_ref' => redirect('https://www.digitalocean.com/pricing/'), as: :digital_ocean_pricing_no_ref, via: :get
    match '/referral_program' => redirect('https://www.digitalocean.com/referral-program/'), as: :digital_ocean_referral_program, via: :get
    match '/referral_program_no_ref' => redirect('https://www.digitalocean.com/referral-program/?refcode=758af342c81e'), as: :digital_ocean_referral_program_no_ref, via: :get
    match '/control_panel' => redirect('https://cloud.digitalocean.com'), as: :digital_ocean_control_panel, via: :get
    match '/status' => redirect('https://status.digitalocean.com'), as: :digital_ocean_status, via: :get

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

  scope '/external' do
    match '/github_student_developer_pack' => redirect('https://education.github.com/pack'), as: :external_github_student_developer_pack, via: :get
    match '/gitter' => redirect('https://gitter.im/gamocosm/Lobby'), as: :external_gitter, via: :get
  end

  scope '/cuberite' do
    match '/' => redirect('https://cuberite.org'), as: :cuberite_website, via: :get
    match '/repo' => redirect('https://github.com/cuberite/cuberite'), as: :cuberite_repo, via: :get
  end

  Sidekiq::Web.use Rack::Auth::Basic, 'Protected Area' do |u, p|
    u == Gamocosm::SIDEKIQ_ADMIN_USERNAME && p == Gamocosm::SIDEKIQ_ADMIN_PASSWORD
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

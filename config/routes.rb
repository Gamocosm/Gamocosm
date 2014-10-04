require 'sidekiq/web'

Rails.application.routes.draw do

  get '/about', to: 'pages#about', as: :about

  get '/help', to: 'pages#help', as: :help

  get '/tos', to: 'pages#tos', as: :tos

  get '/digital_ocean_setup', to: 'pages#digital_ocean_setup', as: :digital_ocean_setup

  get '/404', to: 'pages#not_found'
  get '/422', to: 'pages#unacceptable'
  get '/500', to: 'pages#internal_error'

  match '/wiki' => redirect('https://github.com/Gamocosm/Gamocosm/wiki'), as: :wiki, via: :get
  match '/issues' => redirect('https://github.com/Gamocosm/Gamocosm/issues'), as: :issues, via: :get
  match '/source' => redirect('https://github.com/Gamocosm/Gamocosm'), as: :source, via: :get
  match '/license' => redirect('https://github.com/Gamocosm/Gamocosm/blob/master/LICENSE'), as: :license, via: :get

  scope '/wiki' do
    match '/ftp_ssh' => redirect('https://github.com/Gamocosm/Gamocosm/wiki/FTP-and-SSH'), as: :wiki_ftp_ssh, via: :get
    match '/minecraft_versions' => redirect('https://github.com/Gamocosm/Gamocosm/wiki/Installing-different-versions-of-Minecraft'), as: :wiki_minecraft_versions, via: :get
  end

  scope '/digital_ocean' do
    match '/pricing' => redirect('https://www.digitalocean.com/pricing/'), as: :digital_ocean_pricing, via: :get
    match '/index' => redirect(Gamocosm.digital_ocean_referral_link), as: :digital_ocean_index, via: :get
    match '/help' => redirect('https://www.digitalocean.com/help/'), as: :digital_ocean_help, via: :get
    match '/control_panel' => redirect('https://cloud.digitalocean.com'), as: :digital_ocean_control_panel, via: :get
  end

  Sidekiq::Web.use Rack::Auth::Basic, 'Protected Area' do |u, p|
    u == Gamocosm.sidekiq_admin_username && p == Gamocosm.sidekiq_admin_password
  end
  mount Sidekiq::Web => '/sidekiq'

  devise_for :users, controllers: { registrations: 'registrations' }

  root to: 'pages#landing'

  resources :minecrafts, path: '/servers' do
    member do
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

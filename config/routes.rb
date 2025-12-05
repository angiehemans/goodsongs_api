# config/routes.rb
Rails.application.routes.draw do
  post '/login', to: 'authentication#authenticate'
  post '/signup', to: 'users#create'

  # Onboarding routes
  get '/onboarding/status', to: 'onboarding#status'
  post '/onboarding/account-type', to: 'onboarding#set_account_type'
  post '/onboarding/complete-fan-profile', to: 'onboarding#complete_fan_profile'
  post '/onboarding/complete-band-profile', to: 'onboarding#complete_band_profile'

  # Profile routes - cleaned up and RESTful
  get '/profile', to: 'users#show'
  patch '/profile', to: 'users#update'
  post '/update-profile', to: 'users#update'  # Keep for frontend compatibility
  get '/users/:username', to: 'users#profile_by_username'
  get '/recently-played', to: 'users#recently_played'
  
  # Spotify OAuth routes - consolidated
  get '/spotify/connect', to: 'spotify#connect'
  get '/auth/spotify/callback', to: 'spotify#callback'
  delete '/spotify/disconnect', to: 'spotify#disconnect'
  get '/spotify/status', to: 'spotify#status'
  
  # Review routes - consolidated
  get '/reviews/user', to: 'reviews#current_user_reviews'
  resources :reviews, except: [:new, :edit]
  get '/feed', to: 'reviews#feed'
  get '/feed/following', to: 'reviews#following_feed'
  get '/users/:user_id/reviews', to: 'reviews#user_reviews'

  # Follow routes
  post '/users/:user_id/follow', to: 'follows#create'
  delete '/users/:user_id/follow', to: 'follows#destroy'
  get '/following', to: 'follows#following'
  get '/followers', to: 'follows#followers'
  get '/users/:user_id/following', to: 'follows#user_following'
  get '/users/:user_id/followers', to: 'follows#user_followers'

  # Notification routes
  get '/notifications', to: 'notifications#index'
  get '/notifications/unread_count', to: 'notifications#unread_count'
  patch '/notifications/:id/read', to: 'notifications#mark_read'
  patch '/notifications/read_all', to: 'notifications#mark_all_read'
  
  # Band routes - consolidated user bands endpoint
  get '/bands/user', to: 'bands#user_bands'
  resources :bands, except: [:new, :edit], param: :slug

  # Admin routes
  get '/admin/users', to: 'admin#users'
  get '/admin/users/:id', to: 'admin#user_detail'
  patch '/admin/users/:id/toggle-disabled', to: 'admin#toggle_disabled'
  delete '/admin/users/:id', to: 'admin#destroy_user'
  get '/admin/bands', to: 'admin#bands'
  patch '/admin/bands/:id/toggle-disabled', to: 'admin#toggle_band_disabled'
  delete '/admin/bands/:id', to: 'admin#destroy_band'
  get '/admin/reviews', to: 'admin#reviews'
  delete '/admin/reviews/:id', to: 'admin#destroy_review'

  # Discover routes (public, no auth required)
  get '/discover/bands', to: 'discover#bands'
  get '/discover/users', to: 'discover#users'
  get '/discover/reviews', to: 'discover#reviews'

  # Health check endpoints
  get '/health', to: proc { [200, {}, ['OK']] }
  get '/up', to: proc { [200, {}, ['OK']] }
end

# config/routes.rb
Rails.application.routes.draw do
  post '/login', to: 'authentication#authenticate'
  post '/signup', to: 'users#create'
  
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
  get '/users/:user_id/reviews', to: 'reviews#user_reviews'
  
  # Band routes - consolidated user bands endpoint
  get '/bands/user', to: 'bands#user_bands'
  resources :bands, except: [:new, :edit], param: :slug
  
  # Health check endpoints
  get '/health', to: proc { [200, {}, ['OK']] }
  get '/up', to: proc { [200, {}, ['OK']] }
end

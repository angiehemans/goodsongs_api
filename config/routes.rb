# config/routes.rb
Rails.application.routes.draw do
  post '/login', to: 'authentication#authenticate'
  post '/signup', to: 'users#create'
  get '/profile', to: 'users#show'
  get '/users/:username', to: 'users#profile_by_username'
  get '/recently-played', to: 'users#recently_played'
  
  # Spotify OAuth routes
  get '/spotify/connect', to: 'spotify#connect'
  get '/spotify/connect-url', to: 'spotify#connect_url'
  get '/spotify/generate-connect-url', to: 'spotify#generate_connect_url'
  get '/auth/spotify/callback', to: 'spotify#callback'
  delete '/spotify/disconnect', to: 'spotify#disconnect'
  get '/spotify/status', to: 'spotify#status'
  
  # Review routes
  get '/reviews/user', to: 'reviews#current_user_reviews'
  resources :reviews, except: [:new, :edit]
  get '/feed', to: 'reviews#feed'
  get '/users/:user_id/reviews', to: 'reviews#user_reviews'
  
  # Band routes
  get '/bands/user', to: 'bands#user_bands'
  resources :bands, except: [:new, :edit], param: :slug
  get '/my-bands', to: 'bands#my_bands'
  
  # Health check endpoint
  get '/health', to: proc { [200, {}, ['OK']] }
end

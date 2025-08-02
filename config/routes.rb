# config/routes.rb
Rails.application.routes.draw do
  post '/auth/login', to: 'authentication#authenticate'
  post '/signup', to: 'users#create'
  get '/profile', to: 'users#show'
  get '/users/:username', to: 'users#profile_by_username'
  
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

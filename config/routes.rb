# config/routes.rb
Rails.application.routes.draw do
  post '/auth/login', to: 'authentication#authenticate'
  post '/signup', to: 'users#create'
  get '/profile', to: 'users#show'
  get '/users/:username', to: 'users#profile_by_username'
  
  # Review routes
  resources :reviews, except: [:new, :edit]
  get '/feed', to: 'reviews#feed'
  get '/users/:user_id/reviews', to: 'reviews#user_reviews'
  
  # Health check endpoint
  get '/health', to: proc { [200, {}, ['OK']] }
end

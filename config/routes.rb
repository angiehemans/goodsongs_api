# config/routes.rb
Rails.application.routes.draw do
  # Letter Opener for viewing emails in development
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  post '/login', to: 'authentication#authenticate'
  post '/signup', to: 'users#create'

  # Email verification routes
  post '/email/resend-confirmation', to: 'email_verification#resend_confirmation'
  post '/email/confirm', to: 'email_verification#confirm'

  # Password reset routes
  post '/password/forgot', to: 'password_reset#create'
  post '/password/reset', to: 'password_reset#update'
  get '/password/validate-token', to: 'password_reset#validate_token'

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
  
  # Last.fm routes
  post '/lastfm/connect', to: 'lastfm#connect'
  delete '/lastfm/disconnect', to: 'lastfm#disconnect'
  get '/lastfm/status', to: 'lastfm#status'
  get '/lastfm/search-artist', to: 'lastfm#search_artist'

  # MusicBrainz search routes
  get '/musicbrainz/search', to: 'musicbrainz_search#search'
  get '/musicbrainz/recording/:mbid', to: 'musicbrainz_search#recording'

  # Discogs search routes
  get '/discogs/search', to: 'discogs_search#search'
  get '/discogs/master/:id', to: 'discogs_search#master'
  get '/discogs/release/:id', to: 'discogs_search#release'
  
  # Review routes - consolidated
  get '/reviews/user', to: 'reviews#current_user_reviews'
  get '/reviews/liked', to: 'review_likes#index'
  resources :reviews, except: [:new, :edit] do
    member do
      post 'like', to: 'review_likes#create'
      delete 'like', to: 'review_likes#destroy'
    end
    resources :comments, controller: 'review_comments', only: [:index, :create, :update, :destroy]
  end
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
  resources :bands, except: [:new, :edit], param: :slug do
    # Events nested under bands
    resources :events, only: [:index, :create], param: :id, controller: 'events'
  end

  # Events standalone routes (for show, update, destroy)
  resources :events, only: [:show, :update, :destroy]

  # Venues routes
  resources :venues, only: [:index, :show, :create]

  # Admin routes
  get '/admin/users', to: 'admin#users'
  get '/admin/users/:id', to: 'admin#user_detail'
  patch '/admin/users/:id', to: 'admin#update_user'
  patch '/admin/users/:id/toggle-disabled', to: 'admin#toggle_disabled'
  delete '/admin/users/:id', to: 'admin#destroy_user'
  get '/admin/bands', to: 'admin#bands'
  get '/admin/bands/:id', to: 'admin#band_detail'
  patch '/admin/bands/:id', to: 'admin#update_band'
  patch '/admin/bands/:id/toggle-disabled', to: 'admin#toggle_band_disabled'
  delete '/admin/bands/:id', to: 'admin#destroy_band'
  get '/admin/reviews', to: 'admin#reviews'
  delete '/admin/reviews/:id', to: 'admin#destroy_review'

  # Discover routes (public, no auth required)
  get '/discover/bands', to: 'discover#bands'
  get '/discover/users', to: 'discover#users'
  get '/discover/reviews', to: 'discover#reviews'
  get '/discover/events', to: 'discover#events'

  # Health check endpoints
  get '/health', to: proc { [200, {}, ['OK']] }
  get '/up', to: proc { [200, {}, ['OK']] }

  # API v1 namespace for scrobbling
  namespace :api do
    namespace :v1 do
      resources :scrobbles, only: [:index, :create, :destroy] do
        collection do
          get :recent
        end
      end
      get 'users/:user_id/scrobbles', to: 'scrobbles#user_scrobbles'
      get 'search', to: 'search#index'
    end
  end
end

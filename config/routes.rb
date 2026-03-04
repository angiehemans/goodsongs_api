# config/routes.rb
Rails.application.routes.draw do
  # Letter Opener for viewing emails in development
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  post '/login', to: 'authentication#authenticate'
  post '/signup', to: 'users#create'

  # Auth routes for token management
  post '/auth/refresh', to: 'authentication#refresh'
  post '/auth/logout', to: 'authentication#logout'
  post '/auth/logout-all', to: 'authentication#logout_all'
  get '/auth/sessions', to: 'authentication#sessions'
  delete '/auth/sessions/:id', to: 'authentication#revoke_session'

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
  get '/users/search', to: 'user_search#index'
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

  # Artwork search routes (aggregates from multiple sources)
  get '/artwork/search', to: 'artwork_search#search'

  # Artwork refresh routes
  post '/artwork/refresh/track/:id', to: 'artwork#refresh_track'
  post '/artwork/refresh/album/:id', to: 'artwork#refresh_album'
  post '/artwork/refresh/scrobble/:id', to: 'artwork#refresh_scrobble'

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

  # Comment likes
  post '/comments/:comment_id/like', to: 'review_comment_likes#create'
  delete '/comments/:comment_id/like', to: 'review_comment_likes#destroy'

  # Notification routes
  get '/notifications', to: 'notifications#index'
  get '/notifications/unread_count', to: 'notifications#unread_count'
  patch '/notifications/:id/read', to: 'notifications#mark_read'
  patch '/notifications/read_all', to: 'notifications#mark_all_read'

  # Device tokens for push notifications
  post '/device_tokens', to: 'device_tokens#create'
  delete '/device_tokens', to: 'device_tokens#destroy'

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
  post '/admin/bands/:id/enrich', to: 'admin#enrich_band'
  delete '/admin/bands/:id', to: 'admin#destroy_band'
  get '/admin/reviews', to: 'admin#reviews'
  post '/admin/reviews/:id/enrich', to: 'admin#enrich_review'
  delete '/admin/reviews/:id', to: 'admin#destroy_review'

  # Admin RBAC routes
  namespace :admin do
    resources :plans, only: [:index, :show, :update] do
      collection do
        get :compare
      end
      member do
        post 'abilities/:ability_id', action: :add_ability
        delete 'abilities/:ability_id', action: :remove_ability
      end
    end
    resources :abilities, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get :categories
      end
    end
  end

  # Public blog routes (by username)
  # /blogs/:username is an alias for /users/:username (returns full profile with reviews + posts)
  get 'blogs/:username', to: 'users#profile_by_username', as: :user_blog
  get 'blogs/:username/:slug', to: 'posts#show', as: :blog_post

  # Authenticated post management
  get '/posts/liked', to: 'post_likes#index'
  resources :posts, except: [:new, :edit, :index, :show] do
    collection do
      get :my, to: 'posts#my_posts'
    end
    member do
      post 'like', to: 'post_likes#create'
      delete 'like', to: 'post_likes#destroy'
    end
    resources :comments, controller: 'post_comments', only: [:index, :create, :update, :destroy]
  end
  # GET /posts/:id for owner to fetch their post for editing
  get '/posts/:id', to: 'posts#show_by_id', as: :post_by_id

  # Post comment actions (standalone endpoints)
  post '/post_comments/claim', to: 'post_comments#claim'
  post '/post_comments/:comment_id/like', to: 'post_comment_likes#create'
  delete '/post_comments/:comment_id/like', to: 'post_comment_likes#destroy'

  # Blog image uploads for post content
  resources :blog_images, only: [:create]

  # Discover routes (public, no auth required)
  get '/discover/search', to: 'discover#search'
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
      # Fan dashboard - combined endpoint for all dashboard data
      get 'fan_dashboard', to: 'fan_dashboard#show'

      # Blogger dashboard - combined endpoint for blogger dashboard data
      get 'blogger_dashboard', to: 'blogger_dashboard#show'

      # Blog dashboard - comprehensive analytics dashboard for bloggers
      get 'blog_dashboard', to: 'blog_dashboard#show'

      resources :scrobbles, only: [:index, :create, :destroy] do
        collection do
          get :recent
          post :from_lastfm
        end
        member do
          post :refresh_artwork
          patch :artwork, action: :update_artwork
          delete :artwork, action: :clear_artwork
        end
      end
      get 'users/:user_id/scrobbles', to: 'scrobbles#user_scrobbles'
      get 'search', to: 'search#index'

      # Tracking (unauthenticated)
      post 'track', to: 'tracking#create'

      # Analytics dashboard (authenticated + ability gated)
      get 'analytics/overview', to: 'analytics#overview'
      get 'analytics/views_over_time', to: 'analytics#views_over_time'
      get 'analytics/traffic_sources', to: 'analytics#traffic_sources'
      get 'analytics/content_performance', to: 'analytics#content_performance'
      get 'analytics/geography', to: 'analytics#geography'
      get 'analytics/devices', to: 'analytics#devices'

      # Profile customization (authenticated + ability gated)
      resource :profile_theme, only: [:show, :update] do
        post :publish
        post :discard_draft
        post :reset
      end
      resources :profile_assets, only: [:index, :create, :destroy]

      # Public profiles (no auth required)
      get 'profiles/:username', to: 'profiles#show'
    end
  end
end

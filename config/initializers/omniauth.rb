# Commenting out OmniAuth middleware since we're handling OAuth manually
# Rails.application.config.middleware.use OmniAuth::Builder do
#   provider :spotify, ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_CLIENT_SECRET'], scope: 'user-read-recently-played user-read-email'
#   
#   # Configure OmniAuth for API-only mode
#   configure do |config|
#     config.path_prefix = '/auth'
#     config.silence_get_warning = true
#   end
# end
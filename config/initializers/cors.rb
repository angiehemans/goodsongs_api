# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    allowed_origins = ['https://www.goodsongs.app', 'https://goodsongs.app']

    if Rails.env.development? || Rails.env.test?
      allowed_origins += ['http://localhost:3000', 'http://localhost:3001', 'http://127.0.0.1:3000', 'http://127.0.0.1:3001']
    end

    origins *allowed_origins

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end

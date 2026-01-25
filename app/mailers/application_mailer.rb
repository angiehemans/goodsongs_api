class ApplicationMailer < ActionMailer::Base
  default from: '"GoodSongs" <noreply@mg.goodsongs.app>'
  layout "mailer"
  helper_method :api_url

  private

  def frontend_url
    ENV.fetch('FRONTEND_URL', 'https://goodsongs.app')
  end

  def api_url
    ENV.fetch('API_URL', 'https://api.goodsongs.app')
  end
end

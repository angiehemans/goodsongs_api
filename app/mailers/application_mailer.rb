class ApplicationMailer < ActionMailer::Base
  default from: '"GoodSongs" <noreply@goodsongs.app>'
  layout "mailer"

  private

  def frontend_url
    ENV.fetch('FRONTEND_URL', 'https://goodsongs.app')
  end
end

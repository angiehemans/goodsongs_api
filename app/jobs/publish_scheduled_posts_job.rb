class PublishScheduledPostsJob < ApplicationJob
  queue_as :default

  def perform
    posts = Post.ready_to_publish

    posts.find_each do |post|
      post.update!(status: :published)
      Rails.logger.info("Published scheduled post ##{post.id}: #{post.title}")
    end

    Rails.logger.info("PublishScheduledPostsJob: Published #{posts.count} scheduled posts")
  end
end

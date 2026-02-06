class NotificationsController < ApplicationController
  extend ImageUrlHelper

  before_action :authenticate_request

  # GET /notifications
  def index
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min

    notifications = current_user.notifications.recent
    total_count = notifications.count
    paginated_notifications = notifications.offset((page - 1) * per_page).limit(per_page)

    json_response({
      notifications: paginated_notifications.map { |n| notification_data(n) },
      unread_count: current_user.notifications.unread.count,
      pagination: pagination_meta(page, per_page, total_count)
    })
  end

  # GET /notifications/unread_count
  def unread_count
    json_response({ unread_count: current_user.notifications.unread.count })
  end

  # PATCH /notifications/:id/read
  def mark_read
    notification = current_user.notifications.find(params[:id])
    notification.update!(read: true)
    json_response({ message: 'Notification marked as read', notification: notification_data(notification) })
  end

  # PATCH /notifications/read_all
  def mark_all_read
    current_user.notifications.unread.update_all(read: true)
    json_response({ message: 'All notifications marked as read' })
  end

  private

  def notification_data(notification)
    data = {
      id: notification.id,
      type: notification.notification_type,
      read: notification.read,
      created_at: notification.created_at
    }

    # Add actor info if present
    if notification.actor && !notification.actor.disabled?
      data[:actor] = {
        id: notification.actor.id,
        username: notification.actor.username,
        display_name: notification.actor.display_name,
        profile_image_url: self.class.profile_image_url(notification.actor)
      }
    end

    # Add context based on notification type
    case notification.notification_type
    when 'new_follower'
      data[:message] = "#{notification.actor&.display_name || 'Someone'} started following you"
    when 'new_review'
      if notification.notifiable.is_a?(Review)
        review = notification.notifiable
        data[:message] = "#{notification.actor&.display_name || 'Someone'} reviewed #{review.song_name}"
        data[:review] = {
          id: review.id,
          song_name: review.song_name,
          band_name: review.band_name
        }
      end
    when 'review_like'
      if notification.notifiable.is_a?(Review)
        review = notification.notifiable
        data[:message] = "#{notification.actor&.display_name || 'Someone'} liked your review of #{review.song_name}"
        data[:review] = {
          id: review.id,
          song_name: review.song_name,
          band_name: review.band_name
        }
      end
    when 'review_comment'
      if notification.notifiable.is_a?(ReviewComment)
        comment = notification.notifiable
        review = comment.review
        data[:message] = "#{notification.actor&.display_name || 'Someone'} commented on your review of #{review.song_name}"
        data[:review] = {
          id: review.id,
          song_name: review.song_name,
          band_name: review.band_name
        }
        data[:comment] = {
          id: comment.id,
          body: comment.body.truncate(100)
        }
      end
    end

    data
  end

  def pagination_meta(page, per_page, total_count)
    total_pages = (total_count.to_f / per_page).ceil
    {
      current_page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_next_page: page < total_pages,
      has_previous_page: page > 1
    }
  end
end

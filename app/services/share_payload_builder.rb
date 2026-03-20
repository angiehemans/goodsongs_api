# frozen_string_literal: true

class SharePayloadBuilder
  MAX_THREADS_CHARS = 500

  ALLOWED_TYPES = %w[Review Post Event].freeze

  def initialize(postable)
    @postable = postable
  end

  def build
    text = build_text

    {
      text: text,
      url: canonical_url,
      image_url: resolve_image_url,
      threads_intent_url: threads_intent_url(text),
      instagram_intent_url: nil
    }
  end

  private

  def build_text
    body = case @postable
           when Review
             parts = []
             parts << "\"#{@postable.song_name}\" by #{@postable.band_name}" if @postable.band_name.present?
             parts << "- #{@postable.review_text}" if @postable.review_text.present?
             parts.join(" ")
           when Post
             @postable.title
           when Event
             parts = [@postable.name]
             parts << "at #{@postable.venue.name}" if @postable.venue
             parts << @postable.event_date.strftime("%B %-d, %Y") if @postable.event_date
             parts.join(" — ")
           end

    suffix = case @postable
             when Review then "Recommended on #{canonical_url}"
             else canonical_url
             end

    truncate_for_threads("#{body}\n\n#{suffix}")
  end

  def resolve_image_url
    case @postable
    when Review
      ReviewSerializer.resolved_artwork_url(@postable)
    when Post
      @postable.featured_image_url
    when Event
      EventSerializer.event_image_url(@postable)
    end
  end

  def canonical_url
    @canonical_url ||= build_canonical_url
  end

  def build_canonical_url
    frontend_host = ENV.fetch("FRONTEND_URL", "https://goodsongs.app")

    case @postable
    when Review
      username = @postable.user.username
      "#{frontend_host}/users/#{username}/reviews/#{@postable.id}"
    when Post
      username = @postable.user.username
      "#{frontend_host}/blogs/#{username}/#{@postable.slug}"
    when Event
      "#{frontend_host}/events/#{@postable.id}"
    end
  end

  def threads_intent_url(text)
    "https://www.threads.net/intent/post?text=#{CGI.escape(text)}"
  end

  def truncate_for_threads(text)
    return text if text.length <= MAX_THREADS_CHARS

    url_length = canonical_url.length + 2 # for the \n\n
    max_body = MAX_THREADS_CHARS - url_length
    body = text[0, max_body - 1]
    "#{body}…\n\n#{canonical_url}"
  end
end

module ProfileLinkHelper
  # Build hash of band's configured streaming links
  def self.streaming_links(band)
    return {} unless band

    links = {}
    links['spotify'] = band.spotify_link if band.spotify_link.present?
    links['appleMusic'] = band.apple_music_link if band.apple_music_link.present?
    links['bandcamp'] = band.bandcamp_link if band.bandcamp_link.present?
    links['soundcloud'] = band.soundcloud_link if band.soundcloud_link.present?
    links['youtubeMusic'] = band.youtube_music_link if band.youtube_music_link.present?
    links
  end

  # Build hash of user's configured social links (band links take precedence for band users)
  def self.social_links(user, band = nil)
    links = {}

    ProfileSectionFields::SOCIAL_LINK_TYPES.each do |platform|
      field = "#{platform}_url"

      if user.respond_to?(field) && user.send(field).present?
        links[platform] = user.send(field)
      end

      if band && band.respond_to?(field) && band.send(field).present?
        links[platform] = band.send(field) if user.band?
        links[platform] ||= band.send(field)
      end
    end

    links
  end
end

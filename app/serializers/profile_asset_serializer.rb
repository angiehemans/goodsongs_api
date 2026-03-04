class ProfileAssetSerializer
  def self.full(asset)
    return nil unless asset

    {
      id: asset.id,
      purpose: asset.purpose,
      url: asset.image_url,
      thumbnail_url: asset.thumbnail_url,
      file_type: asset.file_type,
      file_size: asset.file_size,
      created_at: asset.created_at
    }
  end
end

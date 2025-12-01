# app/controllers/onboarding_controller.rb
class OnboardingController < ApplicationController
  skip_before_action :require_onboarding_completed

  def status
    response_data = {
      onboarding_completed: current_user.onboarding_completed,
      account_type: current_user.account_type
    }

    # Include primary band info for BAND accounts
    if current_user.band? && current_user.primary_band
      response_data[:primary_band] = BandSerializer.summary(current_user.primary_band)
    end

    json_response(response_data)
  end

  # Step 1: Choose account type (FAN or BAND)
  def set_account_type
    account_type = params[:account_type]&.downcase

    unless %w[fan band].include?(account_type)
      return json_response({ error: 'Invalid account type. Must be "fan" or "band"' }, :unprocessable_entity)
    end

    # Don't mark onboarding complete yet - profile setup still needed
    if current_user.update(account_type: account_type)
      json_response({
        message: 'Account type set successfully',
        account_type: current_user.account_type,
        onboarding_completed: false,
        next_step: account_type == 'fan' ? 'complete_fan_profile' : 'complete_band_profile'
      })
    else
      json_response({ errors: current_user.errors.full_messages }, :unprocessable_entity)
    end
  end

  # Step 2a: Complete FAN profile (username required)
  def complete_fan_profile
    unless current_user.fan?
      return json_response({ error: 'This endpoint is only for FAN accounts' }, :unprocessable_entity)
    end

    if current_user.onboarding_completed?
      return json_response({ error: 'Onboarding already completed' }, :unprocessable_entity)
    end

    user_attrs = fan_profile_params.merge(onboarding_completed: true)

    if current_user.update(user_attrs)
      json_response({
        message: 'Fan profile completed successfully',
        user: UserSerializer.profile_data(current_user)
      })
    else
      json_response({ errors: current_user.errors.full_messages }, :unprocessable_entity)
    end
  end

  # Step 2b: Complete BAND profile (creates primary band)
  def complete_band_profile
    unless current_user.band?
      return json_response({ error: 'This endpoint is only for BAND accounts' }, :unprocessable_entity)
    end

    if current_user.onboarding_completed?
      return json_response({ error: 'Onboarding already completed' }, :unprocessable_entity)
    end

    ActiveRecord::Base.transaction do
      # Create the band
      band = current_user.bands.build(band_profile_params)

      unless band.save
        return json_response({ errors: band.errors.full_messages }, :unprocessable_entity)
      end

      # Set as primary band and complete onboarding
      unless current_user.update(primary_band: band, onboarding_completed: true)
        raise ActiveRecord::Rollback
        return json_response({ errors: current_user.errors.full_messages }, :unprocessable_entity)
      end

      json_response({
        message: 'Band profile completed successfully',
        user: UserSerializer.profile_data(current_user),
        band: BandSerializer.full(band)
      })
    end
  end

  private

  def fan_profile_params
    params.permit(:username, :about_me, :profile_image)
  end

  def band_profile_params
    params.permit(:name, :about, :location, :spotify_link, :bandcamp_link,
                  :apple_music_link, :youtube_music_link, :profile_picture)
  end
end

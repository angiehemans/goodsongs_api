# app/controllers/concerns/ability_check.rb
module AbilityCheck
  extend ActiveSupport::Concern

  private

  def require_ability!(ability_key)
    return if current_user&.can?(ability_key)

    render json: {
      error: "upgrade_required",
      message: "This feature requires an upgrade.",
      required_ability: ability_key,
      upgrade_plan: current_user&.upgrade_plan_for(ability_key)&.key
    }, status: :forbidden
  end
end

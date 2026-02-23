module Admin
  class PlansController < ApplicationController
    before_action :require_admin
    before_action :set_plan, only: [:show, :update, :add_ability, :remove_ability]

    # GET /admin/plans
    def index
      plans = Plan.all.order(:role, :price_cents_monthly)
      json_response({
        plans: plans.map { |p| PlanSerializer.full(p) }
      })
    end

    # GET /admin/plans/:id
    def show
      json_response({
        plan: PlanSerializer.with_abilities(@plan)
      })
    end

    # PATCH /admin/plans/:id
    def update
      if @plan.update(plan_params)
        json_response({
          message: "Plan updated successfully",
          plan: PlanSerializer.with_abilities(@plan)
        })
      else
        json_response({ errors: @plan.errors.full_messages }, :unprocessable_entity)
      end
    end

    # GET /admin/plans/compare
    def compare
      plans = Plan.all.includes(:abilities).order(:role, :price_cents_monthly)
      abilities = Ability.all.ordered

      matrix = abilities.map do |ability|
        row = { ability: AbilitySerializer.summary(ability) }
        plans.each do |plan|
          row[plan.key] = plan.abilities.include?(ability)
        end
        row
      end

      json_response({
        plans: plans.map { |p| { key: p.key, name: p.name, role: p.role } },
        abilities: matrix
      })
    end

    # POST /admin/plans/:id/abilities/:ability_id
    def add_ability
      ability = Ability.find(params[:ability_id])
      plan_ability = @plan.plan_abilities.find_or_create_by(ability: ability)

      if plan_ability.persisted?
        # Clear abilities cache for all users on this plan
        @plan.users.find_each(&:clear_abilities_cache!)

        json_response({
          message: "Ability '#{ability.name}' added to plan '#{@plan.name}'",
          plan: PlanSerializer.with_abilities(@plan)
        })
      else
        json_response({ errors: plan_ability.errors.full_messages }, :unprocessable_entity)
      end
    end

    # DELETE /admin/plans/:id/abilities/:ability_id
    def remove_ability
      ability = Ability.find(params[:ability_id])
      plan_ability = @plan.plan_abilities.find_by(ability: ability)

      if plan_ability&.destroy
        # Clear abilities cache for all users on this plan
        @plan.users.find_each(&:clear_abilities_cache!)

        json_response({
          message: "Ability '#{ability.name}' removed from plan '#{@plan.name}'",
          plan: PlanSerializer.with_abilities(@plan)
        })
      else
        json_response({ error: "Ability not found on this plan" }, :not_found)
      end
    end

    private

    def set_plan
      @plan = Plan.find(params[:id])
    end

    def plan_params
      params.permit(:name, :price_cents_monthly, :price_cents_annual, :active)
    end
  end
end

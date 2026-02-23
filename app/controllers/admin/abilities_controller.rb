module Admin
  class AbilitiesController < ApplicationController
    before_action :require_admin
    before_action :set_ability, only: [:show, :update, :destroy]

    # GET /admin/abilities
    def index
      abilities = Ability.all.ordered.includes(:plans)

      # Group by category if requested
      if params[:grouped] == "true"
        grouped = abilities.group_by(&:category).transform_values do |category_abilities|
          category_abilities.map { |a| AbilitySerializer.full(a) }
        end
        json_response({ abilities: grouped })
      else
        json_response({
          abilities: abilities.map { |a| AbilitySerializer.full(a) }
        })
      end
    end

    # GET /admin/abilities/:id
    def show
      json_response({
        ability: AbilitySerializer.full(@ability)
      })
    end

    # POST /admin/abilities
    def create
      ability = Ability.new(ability_params)

      if ability.save
        json_response({
          message: "Ability '#{ability.name}' created successfully",
          ability: AbilitySerializer.full(ability)
        }, :created)
      else
        json_response({ errors: ability.errors.full_messages }, :unprocessable_entity)
      end
    end

    # PATCH /admin/abilities/:id
    def update
      if @ability.update(ability_params)
        json_response({
          message: "Ability '#{@ability.name}' updated successfully",
          ability: AbilitySerializer.full(@ability)
        })
      else
        json_response({ errors: @ability.errors.full_messages }, :unprocessable_entity)
      end
    end

    # DELETE /admin/abilities/:id
    def destroy
      # Check if ability is used by any plans
      if @ability.plans.any?
        plan_names = @ability.plans.pluck(:name).join(", ")
        return json_response({
          error: "Cannot delete ability '#{@ability.name}' because it is used by: #{plan_names}",
          plans: @ability.plans.map { |p| { key: p.key, name: p.name } }
        }, :unprocessable_entity)
      end

      @ability.destroy
      json_response({
        message: "Ability '#{@ability.name}' deleted successfully"
      })
    end

    # GET /admin/abilities/categories
    def categories
      json_response({
        categories: Ability::CATEGORIES
      })
    end

    private

    def set_ability
      @ability = Ability.find(params[:id])
    end

    def ability_params
      params.permit(:key, :name, :description, :category)
    end
  end
end

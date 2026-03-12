module Paginatable
  extend ActiveSupport::Concern

  private

  def page_param
    (params[:page] || 1).to_i
  end

  def per_page_param(default: 20, max: 100)
    [(params[:per_page] || default).to_i, max].min
  end

  def paginate(scope, default: 20, max: 100)
    page = page_param
    per_page = per_page_param(default: default, max: max)
    scope.offset((page - 1) * per_page).limit(per_page)
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

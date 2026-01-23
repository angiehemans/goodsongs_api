# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include ApiErrorHandler

      # Inherits authentication from ApplicationController
      # ApiErrorHandler provides standardized error responses per PRD spec
    end
  end
end

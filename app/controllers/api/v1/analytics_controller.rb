# frozen_string_literal: true

module Api
  module V1
    class AnalyticsController < BaseController
      before_action :require_analytics_ability

      VALID_PERIODS = %w[7d 30d 90d custom].freeze
      DEFAULT_PERIOD = '30d'

      # GET /api/v1/analytics/overview
      def overview
        views = page_views_in_period
        previous_views = page_views_in_previous_period

        current_count = views.count
        previous_count = previous_views.count
        current_unique = views.unique_sessions_count
        previous_unique = previous_views.unique_sessions_count

        render json: {
          data: {
            total_views: current_count,
            total_views_change: percentage_change(previous_count, current_count),
            unique_visitors: current_unique,
            unique_visitors_change: percentage_change(previous_unique, current_unique),
            period: period_param,
            start_date: period_start.iso8601,
            end_date: period_end.iso8601
          }
        }
      end

      # GET /api/v1/analytics/views_over_time
      def views_over_time
        views = page_views_in_period

        grouped = case period_param
                  when '7d'
                    views.group_by_day(:created_at, time_zone: Time.zone.name).count
                  when '30d'
                    views.group_by_day(:created_at, time_zone: Time.zone.name).count
                  when '90d'
                    views.group_by_week(:created_at, time_zone: Time.zone.name).count
                  else
                    views.group_by_day(:created_at, time_zone: Time.zone.name).count
                  end

        render json: {
          data: {
            views: grouped.map { |date, count| { date: date.to_date.iso8601, views: count } },
            period: period_param
          }
        }
      end

      # GET /api/v1/analytics/traffic_sources
      def traffic_sources
        views = page_views_in_period
        total = views.count

        sources = views.group(:referrer_source).count
        sorted = sources.sort_by { |_, count| -count }

        render json: {
          data: {
            sources: sorted.map do |(source, count)|
              {
                source: source,
                views: count,
                percentage: total > 0 ? (count.to_f / total * 100).round(1) : 0
              }
            end,
            total: total,
            period: period_param
          }
        }
      end

      # GET /api/v1/analytics/content_performance
      def content_performance
        views = page_views_in_period

        content_stats = views
          .group(:viewable_type, :viewable_id)
          .count
          .sort_by { |_, count| -count }
          .first(20)

        content_data = content_stats.map do |(type_id, count)|
          viewable_type, viewable_id = type_id
          viewable = viewable_type.constantize.find_by(id: viewable_id)

          next unless viewable

          {
            type: viewable_type.downcase,
            id: viewable_id,
            title: content_title(viewable),
            views: count,
            path: content_path(viewable)
          }
        end.compact

        render json: {
          data: {
            content: content_data,
            period: period_param
          }
        }
      end

      # GET /api/v1/analytics/geography
      def geography
        views = page_views_in_period
        total = views.count

        countries = views.where.not(country: nil).group(:country).count
        sorted = countries.sort_by { |_, count| -count }

        render json: {
          data: {
            countries: sorted.map do |(country, count)|
              {
                country: country,
                views: count,
                percentage: total > 0 ? (count.to_f / total * 100).round(1) : 0
              }
            end,
            unknown: views.where(country: nil).count,
            total: total,
            period: period_param
          }
        }
      end

      # GET /api/v1/analytics/devices
      def devices
        views = page_views_in_period
        total = views.count

        devices = views.group(:device_type).count

        render json: {
          data: {
            devices: devices.map do |device_type, count|
              {
                device: device_type,
                views: count,
                percentage: total > 0 ? (count.to_f / total * 100).round(1) : 0
              }
            end,
            total: total,
            period: period_param
          }
        }
      end

      private

      def require_analytics_ability
        require_ability!(:view_analytics)
      end

      def page_views_in_period
        PageView.for_owner(current_user).in_period(period_start, period_end)
      end

      def page_views_in_previous_period
        duration = period_end - period_start
        previous_start = period_start - duration
        previous_end = period_start

        PageView.for_owner(current_user).in_period(previous_start, previous_end)
      end

      def period_param
        param = params[:period].presence || DEFAULT_PERIOD
        VALID_PERIODS.include?(param) ? param : DEFAULT_PERIOD
      end

      def period_start
        @period_start ||= case period_param
                          when '7d' then 7.days.ago.beginning_of_day
                          when '30d' then 30.days.ago.beginning_of_day
                          when '90d' then 90.days.ago.beginning_of_day
                          when 'custom' then parse_custom_date(params[:start_date], 30.days.ago)
                          else 30.days.ago.beginning_of_day
                          end
      end

      def period_end
        @period_end ||= case period_param
                        when 'custom' then parse_custom_date(params[:end_date], Time.current)
                        else Time.current.end_of_day
                        end
      end

      def parse_custom_date(date_string, default)
        return default if date_string.blank?
        Time.zone.parse(date_string)
      rescue ArgumentError
        default
      end

      def percentage_change(previous, current)
        return 0 if previous.zero?
        ((current - previous).to_f / previous * 100).round(1)
      end

      def content_title(viewable)
        case viewable
        when Post then viewable.title
        when Band then viewable.name
        when Event then viewable.name
        else viewable.try(:title) || viewable.try(:name) || "Unknown"
        end
      end

      def content_path(viewable)
        case viewable
        when Post then "/blogs/#{viewable.user.username}/#{viewable.slug}"
        when Band then "/bands/#{viewable.slug}"
        when Event then "/events/#{viewable.id}"
        else nil
        end
      end
    end
  end
end

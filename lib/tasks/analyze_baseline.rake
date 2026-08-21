# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

namespace :db do
  desc 'Collect baseline API/database performance metrics and write to tmp/baseline_metrics.json'
  task analyze_baseline: :environment do
    include DatabaseHelper

    BASELINE_OUTPUT_PATH = Rails.root.join('tmp/baseline_metrics.json')
    RUNS_PER_ENDPOINT = ENV.fetch('BASELINE_RUNS_PER_ENDPOINT', '3').to_i

    API_HOST = ENV.fetch('BASELINE_API_HOST', 'http://localhost:3000')
    API_KEY = ENV.fetch('BASELINE_API_KEY', nil)
    API_SECRET = ENV.fetch('BASELINE_API_SECRET', nil)

    # rubocop:disable Style/CombinableLoops
    ENDPOINTS = {
      public_read: [
        { method: :get, path: '/api/v1/channels/recommend_channels' },
        { method: :get, path: '/api/v1/channels/search', query: { q: 'news' } },
        { method: :get, path: '/api/v1/channels/group_recommended_channels' },
        { method: :get, path: '/api/v1/channels/channel_detail', query: { id: 'news' } },
        { method: :get, path: '/api/v1/channels/bridge_information', query: { id: 1 } },
        { method: :get, path: '/api/v1/channels/starter_packs_detail', query: { id: 'news' } },
        { method: :get, path: '/api/v1/collections' },
        { method: :get, path: '/api/v1/collections/fetch_channels' },
        { method: :get, path: '/api/v1/collections/newsmast_collections' },
        { method: :get, path: '/api/v1/collections/channel_feed_collections' },
        { method: :get, path: '/api/v1/communities/community_types' },
        { method: :get, path: '/api/v1/communities/collections' },
        { method: :get, path: '/api/v1/communities/contributor_list', query: { id: 'news' } },
        { method: :get, path: '/api/v1/communities/search_contributor', query: { id: 'news', q: 'john' } },
        { method: :get, path: '/api/v1/communities/mute_contributor_list', query: { id: 'news' } },
        { method: :get, path: '/api/v1/communities/hashtag_list', query: { id: 'news' } },
        { method: :get, path: '/api/v1/communities/post_hashtag_list', query: { id: 'news' } },
        { method: :get, path: '/api/v1/content_types' },
        { method: :get, path: '/api/v1/domains/verify', query: { domain: 'example.com' } },
        { method: :get, path: '/api/v1/general_icons' },
        { method: :get, path: '/api/v1/social_icons' },
        { method: :get, path: '/api/v1/app_versions/check_version', query: { app_name: 'patchwork', version: '1.0.0' } },
        { method: :get, path: '/api/v1/server_settings' },
        { method: :get, path: '/api/v1/server_settings/menu_visibility' },
        { method: :get, path: '/api/v1/locales' },
        { method: :get, path: '/api/v1/custom_menus/display', query: { app_name: 'patchwork' } },
        { method: :get, path: '/api/v1/categories/bristol_latest_print' },
        { method: :get, path: '/api/v1/users/bluesky_bridge' }
      ],
      authenticated_read: [
        { method: :get, path: '/api/v1/channels/channel_feeds', auth: :bearer },
        { method: :get, path: '/api/v1/channels/newsmast_channels', auth: :bearer },
        { method: :get, path: '/api/v1/channels/my_channel', auth: :bearer },
        { method: :get, path: '/api/v1/channels/mo_me_channels', auth: :bearer },
        { method: :get, path: '/api/v1/channels/patchwork_demo_channels', auth: :bearer },
        { method: :get, path: '/api/v1/channels/toot_channels', auth: :bearer },
        { method: :get, path: '/api/v1/channels/bristol_cable_channels', auth: :bearer },
        { method: :get, path: '/api/v1/channels/find_out_channels', auth: :bearer },
        { method: :get, path: '/api/v1/channels/find_out_catch_up', auth: :bearer },
        { method: :get, path: '/api/v1/channels/find_out_speak_out', auth: :bearer },
        { method: :get, path: '/api/v1/channels/leicester_channels', auth: :bearer },
        { method: :get, path: '/api/v1/channels/csidnet_channels', auth: :bearer },
        { method: :get, path: '/api/v1/channels/brazilian_museum_channels', auth: :bearer },
        { method: :get, path: '/api/v1/joined_communities', auth: :bearer },
        { method: :get, path: '/api/v1/joined_working_groups', auth: :bearer },
        { method: :get, path: '/api/v1/locales/user_preference', auth: :bearer },
        { method: :get, path: '/api/v1/community_admins', auth: :bearer },
        { method: :get, path: '/api/v1/community_admins/boost_bot_accounts', auth: :bearer }
      ],
      authenticated_write_admin: [
        { method: :post, path: '/api/v1/joined_communities', query: { id: 1 }, auth: :bearer },
        { method: :post, path: '/api/v1/joined_communities/set_primary', query: { id: 1, platform_type: 'newsmast.social' }, auth: :bearer },
        { method: :post, path: '/api/v1/joined_working_groups', query: { id: 1 }, auth: :bearer },
        { method: :post, path: '/api/v1/joined_working_groups/set_primary', query: { id: 1, platform_type: 'newsmast.social' }, auth: :bearer },
        { method: :post, path: '/api/v1/statuses/boost_post', query: { status_id: 1 }, auth: :bearer },
        { method: :post, path: '/api/v1/users/bluesky_bridge', query: { bluesky_bridge: true }, auth: :bearer },
        { method: :patch, path: '/api/v1/channels/change_boost_bot_profile', query: { id: 'boost-bot' }, auth: :bearer },
        { method: :post, path: '/api/v1/community_admins/modify_account_status', query: { account_id: 1, status: 'active' }, auth: :bearer },
        { method: :post, path: '/api/v1/settings/upsert', query: { key: 'foo', value: 'bar' }, auth: :bearer },
        { method: :post, path: '/api/v1/locales/set', query: { locale: 'en' }, auth: :bearer },
        { method: :post, path: '/api/v1/locales/save_preference', query: { locale: 'en' }, auth: :bearer },
        { method: :patch, path: '/api/v1/api_key/rotate', auth: :bearer }
      ]
    }.freeze
    # rubocop:enable Style/CombinableLoops

    def percentile(values, p)
      return 0.0 if values.empty?

      sorted = values.sort
      k = (sorted.length - 1) * p / 100.0
      lower = k.floor
      upper = k.ceil
      return sorted[lower] if lower == upper

      sorted[lower] + (k - lower) * (sorted[upper] - sorted[lower])
    end

    def status_summary(counts)
      counts.map { |status, count| "#{status}:#{count}" }.join(',')
    end

    def api_headers
      headers = { 'Accept' => 'application/json' }
      headers['x-api-key'] = API_KEY if API_KEY
      headers['x-api-secret'] = API_SECRET if API_SECRET
      headers
    end

    def make_request(method, path, query, auth)
      uri = URI.join(API_HOST, path)
      uri.query = URI.encode_www_form(query) if query&.any?

      req = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
      api_headers.each { |k, v| req[k] = v }

      if auth == :bearer
        return { skipped: true, reason: 'missing credentials for auth=bearer' }
      end

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(req)
      end
    end

    def profile_endpoint(method, path, query, auth)
      run_results = []
      errors = []

      RUNS_PER_ENDPOINT.times do
        query_count = 0
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*_args, payload|
          query_count += 1 if payload[:sql] && !payload[:sql].match?(/^(BEGIN|COMMIT|SAVEPOINT|RELEASE|ROLLBACK)/i)
        end

        start_time = Time.current
        response = make_request(method, path, query, auth)
        elapsed_ms = (Time.current - start_time) * 1000.0
        ActiveSupport::Notifications.unsubscribe(subscriber)

        if response.is_a?(Hash) && response[:skipped]
          return response
        end

        run_results << {
          time_ms: elapsed_ms.round(2),
          query_count: query_count,
          status: response.code.to_i
        }
      rescue StandardError => e
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
        errors << e.message
        run_results << { time_ms: nil, query_count: nil, status: nil, error: e.message }
      end

      latencies = run_results.map { |r| r[:time_ms] }.compact
      query_counts = run_results.map { |r| r[:query_count] }.compact
      status_counts = run_results.group_by { |r| r[:status].to_s }.transform_values(&:count)

      {
        method: method.to_s.upcase,
        runs: RUNS_PER_ENDPOINT,
        status_summary: status_summary(status_counts),
        status_counts: status_counts,
        latency_ms: {
          min: latencies.min&.round(2) || 0.0,
          max: latencies.max&.round(2) || 0.0,
          avg: latencies.empty? ? 0.0 : (latencies.sum / latencies.length).round(2),
          p50: percentile(latencies, 50).round(2),
          p95: percentile(latencies, 95).round(2)
        },
        query_count: {
          min: query_counts.min || 0,
          max: query_counts.max || 0,
          avg: query_counts.empty? ? 0.0 : (query_counts.sum.to_f / query_counts.length).round(2),
          p50: percentile(query_counts, 50).round(2),
          p95: percentile(query_counts, 95).round(2)
        },
        run_results: run_results,
        errors: errors
      }
    end

    request_metrics = {}

    ENDPOINTS.each do |category, endpoints|
      category_results = {}

      endpoints.each do |endpoint|
        puts "Profiling #{category}: #{endpoint[:method].to_s.upcase} #{endpoint[:path]}"
        category_results[endpoint[:path]] = profile_endpoint(
          endpoint[:method],
          endpoint[:path],
          endpoint[:query],
          endpoint[:auth]
        )
      end

      request_metrics[category] = category_results
    end

    database_metrics = {
      total_size: with_read_replica { fetch_database_size },
      active_connections: with_read_replica { fetch_active_connections }
    }

    output = {
      captured_at: Time.current.iso8601,
      run_config: {
        runs_per_endpoint: RUNS_PER_ENDPOINT
      },
      request_metrics: request_metrics,
      database_metrics: database_metrics
    }

    File.write(BASELINE_OUTPUT_PATH, JSON.pretty_generate(output))
    puts "Baseline metrics written to #{BASELINE_OUTPUT_PATH}"
  end

  def fetch_database_size
    result = ActiveRecord::Base.connection.execute(
      "SELECT pg_size_pretty(pg_database_size(current_database())) AS size"
    )
    result.first['size']
  end

  def fetch_active_connections
    result = ActiveRecord::Base.connection.execute(
      "SELECT count(*) AS count FROM pg_stat_activity WHERE datname = current_database()"
    )
    result.first['count'].to_i
  end
end

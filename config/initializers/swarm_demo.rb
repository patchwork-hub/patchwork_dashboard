require 'json'
require 'socket'
require 'time'

class SwarmDemoEndpoint
  PATHS = ['/demo', '/demo/', '/demo/health'].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    enabled = ENV['SWARM_DEMO_ENABLED'] == 'true'
    path = env['PATH_INFO']

    return @app.call(env) unless enabled && PATHS.include?(path)

    unless ['GET', 'HEAD'].include?(env['REQUEST_METHOD'])
      return [
        405,
        { 'Content-Type' => 'text/plain', 'Allow' => 'GET, HEAD' },
        ['Method not allowed']
      ]
    end

    if path == '/demo/health'
      body = JSON.generate(
        status: 'ok',
        scope: 'demo-only',
        container: Socket.gethostname,
        node: ENV.fetch('SWARM_NODE', 'unknown'),
        task: ENV.fetch('SWARM_TASK', 'unknown'),
        release: ENV.fetch('APP_RELEASE', 'v1'),
        time: Time.now.utc.iso8601,
        dependencies_checked: []
      )
      content_type = 'application/json'
    else
      body = File.binread(
        Rails.root.join('lib', 'swarm_demo', 'index.html')
      )
      content_type = 'text/html; charset=utf-8'
    end

    headers = {
      'Content-Type' => content_type,
      'Content-Length' => body.bytesize.to_s,
      'Cache-Control' => 'no-store',
      'X-Content-Type-Options' => 'nosniff',
      'Content-Security-Policy' =>
        "default-src 'none'; script-src 'unsafe-inline'; " \
        "style-src 'unsafe-inline'; connect-src 'self'; " \
        "frame-ancestors 'none'; base-uri 'none'"
    }

    [200, headers, env['REQUEST_METHOD'] == 'HEAD' ? [] : [body]]
  end
end

Rails.application.config.middleware.insert_before 0, SwarmDemoEndpoint
# Optional lab endpoint. It deliberately runs before sessions, authentication,
# and other middleware that may access external services.
require 'cgi'
require 'json'
require 'socket'
require 'time'

class SwarmDemoEndpoint
  def initialize(app)
    @app = app
  end

  def call(env)
    path = env['PATH_INFO']
    enabled = ENV['SWARM_DEMO_ENABLED'] == 'true'
    return @app.call(env) unless enabled && ['/demo', '/demo/', '/demo/health'].include?(path)

    unless ['GET', 'HEAD'].include?(env['REQUEST_METHOD'])
      return [405, { 'Content-Type' => 'text/plain', 'Allow' => 'GET, HEAD' }, ['Method not allowed']]
    end

    hostname = Socket.gethostname
    release = ENV.fetch('APP_RELEASE', 'lab')
    timestamp = Time.now.utc.iso8601

    if path == '/demo/health'
      body = JSON.generate(status: 'ok', scope: 'demo-only', hostname: hostname,
                           release: release, time: timestamp,
                           dependencies_checked: [])
      content_type = 'application/json'
    else
      body = <<~HTML
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Patchwork | Swarm lab</title>
          <style>
            body{margin:0;background:#101827;color:#e8edf5;font:17px/1.6 system-ui,sans-serif}
            main{max-width:760px;margin:8vh auto;padding:32px}
            .badge{color:#79e0b5;text-transform:uppercase;letter-spacing:.12em;font-size:13px}
            h1{font-size:42px;line-height:1.15}section{background:#1c293c;padding:24px;border-radius:16px}
            dt{color:#aabbd2;font-size:14px}dd{margin:0 0 18px;overflow-wrap:anywhere}
            a{color:#79e0b5}small{color:#aabbd2}
          </style>
        </head>
        <body><main>
          <p class="badge">Patchwork / Docker Swarm lab</p>
          <h1>Your application image is serving requests.</h1>
          <p>This separate demo endpoint works without PostgreSQL, Redis, or Mastodon API calls.</p>
          <section><dl>
            <dt>Container hostname (not the Swarm node name)</dt><dd>#{CGI.escapeHTML(hostname)}</dd>
            <dt>Release</dt><dd>#{CGI.escapeHTML(release)}</dd>
            <dt>Response time (UTC)</dt><dd>#{CGI.escapeHTML(timestamp)}</dd>
          </dl><a href="/demo">Refresh response</a> &middot; <a href="/demo/health">Demo health JSON</a></section>
          <p><small>This proves the web process can respond. It does not validate database connectivity,
          login, background jobs, Mastodon integration, or production readiness.</small></p>
        </main></body></html>
      HTML
      content_type = 'text/html; charset=utf-8'
    end

    headers = {
      'Content-Type' => content_type,
      'Content-Length' => body.bytesize.to_s,
      'Cache-Control' => 'no-store',
      'X-Content-Type-Options' => 'nosniff',
      'Content-Security-Policy' => "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'"
    }
    [200, headers, env['REQUEST_METHOD'] == 'HEAD' ? [] : [body]]
  end
end

Rails.application.config.middleware.insert_before 0, SwarmDemoEndpoint

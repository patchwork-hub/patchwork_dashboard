class MonitoringController < ApplicationController
  skip_before_action :authenticate_user!, only: [:benchmark]

  def benchmark
    iterations = params[:iterations].to_i
    iterations = 10 if iterations <= 0 || iterations > 1000

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    total = 0

    iterations.times do
      total += (1 + 2 + 3 + 4 + 5)
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

    render json: {
      ok: true,
      iterations: iterations,
      total: total,
      elapsed_seconds: elapsed.round(6),
      endpoint: '/monitoring/benchmark'
    }
  end
end

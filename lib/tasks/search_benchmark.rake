namespace :performance do
  desc "Benchmark the community substring search plan without changing indexes"
  task community_search: :environment do
    unless ENV['CONFIRM_SEARCH_BENCHMARK'] == '1'
      abort 'Set CONFIRM_SEARCH_BENCHMARK=1 to run EXPLAIN ANALYZE.'
    end

    query = ENV.fetch('QUERY', 'news').downcase
    minimum_rows = ENV.fetch('MINIMUM_ROWS', 10_000).to_i
    row_count = Community.count

    if row_count < minimum_rows
      abort "Community row count #{row_count} is below MINIMUM_ROWS=#{minimum_rows}; the plan is not representative."
    end

    predicate = ActiveRecord::Base.sanitize_sql_array([
      'lower(name) LIKE :query OR lower(slug) LIKE :query',
      { query: "%#{ActiveRecord::Base.sanitize_sql_like(query)}%" }
    ])
    sql = <<~SQL.squish
      EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
      SELECT id FROM #{Community.quoted_table_name}
      WHERE #{predicate}
    SQL

    raw_plan = ActiveRecord::Base.connection.select_value(sql)
    plan = raw_plan.is_a?(String) ? JSON.parse(raw_plan) : raw_plan
    puts JSON.pretty_generate(plan)
  end
end
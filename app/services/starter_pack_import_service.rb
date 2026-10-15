class StarterPackImportService
  class ImportError < StandardError; end

  def initialize(data_dir:, source: nil, dry_run: false, resolve_missing: true, skip_unresolved: false, user: nil, output: $stdout)
    @data_dir = Pathname.new(data_dir)
    @source = source.presence
    @dry_run = dry_run
    @resolve_missing = resolve_missing
    @skip_unresolved = skip_unresolved
    @user = user
    @output = output
  end

  def call
    raise ArgumentError, 'Data directory does not exist' unless @data_dir.directory?
    if @resolve_missing && !@dry_run && @user.nil?
      raise ArgumentError, 'USER_ID is required when resolving missing accounts'
    end

    directories = @data_dir.children.select(&:directory?).sort
    directories.select! { |directory| directory.basename.to_s == @source } if @source
    raise ArgumentError, 'Source directory not found' if @source && directories.empty?

    imports = directories.flat_map { |directory| prepare_directory(directory) }
    StarterPack.transaction do
      imports.each { |entry| import_pack(entry) }
      raise ActiveRecord::Rollback if @dry_run
    end
    @output.puts 'Missing accounts were not resolved during the dry run.' if @dry_run && @resolve_missing
  end

  private

  def prepare_directory(directory)
    list_path = directory.join('starter_pack_list.json')
    return [] unless list_path.file?

    JSON.parse(list_path.read).map do |entry|
      legacy_id = entry.fetch('id').to_s
      raise ArgumentError, 'Invalid legacy pack ID' unless legacy_id.match?(/\A[0-9]+\z/)

      followers_path = directory.join("starter_pack_#{legacy_id}.json")
      raise ArgumentError, 'Missing member data file' unless followers_path.file?

      followers = JSON.parse(followers_path.read)
      @output.puts "Preparing pack #{legacy_id}: #{followers.size} accounts from starter_pack_#{legacy_id}.json"
      creator = find_account(entry['collected_by'], context: "pack #{legacy_id} creator")
      accounts = followers.each_with_index.filter_map do |row, index|
        find_account(row, context: "pack #{legacy_id} member #{index + 1}")
      end.uniq(&:id)
      if @skip_unresolved && !@dry_run && followers.any? && accounts.empty?
        @output.puts "Skipping pack #{legacy_id}: no member accounts resolved; existing pack unchanged"
        next
      end
      { instance_name: directory.basename.to_s.parameterize(separator: ''), title: entry.fetch('title'),
        description: entry['description'], created_by: creator, accounts: accounts,
        legacy_id: legacy_id, original_count: followers.size }
    end.compact
  end

  def import_pack(entry)
    pack = StarterPack.find_or_initialize_by(entry.slice(:instance_name, :title))
    attributes = entry.slice(:description, :created_by)
    attributes.delete(:created_by) if @skip_unresolved && entry[:created_by].nil? && pack.persisted?
    pack.assign_attributes(attributes)
    pack.save!
    pack.with_lock do
      pack.starter_pack_accounts.delete_all
      entry[:accounts].each_with_index do |account, member_position|
        pack.starter_pack_accounts.create!(account: account, position: member_position)
      end
      pack.touch
    end
    @output.puts "#{@dry_run ? 'DRY RUN: ' : ''}pack #{entry[:legacy_id]}: #{entry[:accounts].size}/#{entry[:original_count]} accounts matched; creator #{entry[:created_by] ? 'matched' : 'unmatched'}"
  end

  def find_account(row, context: 'account')
    return unless row.is_a?(Hash)

    account = find_saved_account(row)
    return account if account || !@resolve_missing || @dry_run

    handle = row['acct'].to_s.delete_prefix('@').strip
    queries = [handle.include?('@') ? handle : nil, row['url'].presence, row['uri'].presence].compact.uniq
    queries << handle if queries.empty? && handle.present?
    raise ImportError, "Missing identity for #{context} in starter pack data" if queries.empty?

    queries.each do |query|
      results = StarterPackAccountSearchService.new(query, user: @user).call
      result = results.find do |candidate|
        (handle.present? && candidate[:acct].to_s.delete_prefix('@').casecmp?(handle)) ||
          (row['url'].present? && candidate[:profile_url] == row['url'])
      end
      account = Account.find_by(id: result[:id]) if result
      account ||= find_saved_account(row)
      return account if account
    end
    if @skip_unresolved
      @output.puts "Skipping unresolved #{context} after #{queries.size} search attempts"
      return
    end

    raise ImportError, "Could not resolve #{context} after #{queries.size} search attempts; retry with SKIP_UNRESOLVED=true to skip unavailable accounts"
  rescue StarterPackAccountSearchService::SearchError
    raise ImportError, 'Mastodon account resolution failed; check the instance connection and USER_ID'
  end

  def find_saved_account(row)
    by_uri = Account.find_by(uri: row['uri']) if row['uri'].present?
    return by_uri if by_uri

    by_url = Account.find_by(url: row['url']) if row['url'].present?
    return by_url if by_url

    handle = row['acct'].to_s.delete_prefix('@').strip
    username, domain = handle.split('@', 2)
    return if username.blank?
    return if domain.blank? && (row['url'].present? || row['uri'].present?)

    local_domain = ENV['LOCAL_DOMAIN'].presence || URI.parse(ENV.fetch('MASTODON_INSTANCE_URL', '')).host
    domain = nil if domain.present? && domain.casecmp?(local_domain.to_s)
    Account.where('LOWER(username) = ?', username.downcase).find_by(domain: domain&.downcase)
  end
end
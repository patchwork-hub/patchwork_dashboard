class StarterPackPresenter
  def initialize(pack)
    @pack = pack
  end

  def channel
    {
      id: @pack.id.to_s, title: @pack.title, description: @pack.description,
      collected_by: StarterPackAccountPresenter.new(@pack.created_by).as_json,
      total_accounts: @pack.starter_pack_accounts.size
    }
  end

  def followers
    @pack.starter_pack_accounts.map { |member| StarterPackAccountPresenter.new(member.account).as_json }
  end

  def cache_key
    accounts = [@pack.created_by, *@pack.starter_pack_accounts.map(&:account)].compact
    [@pack.cache_key_with_version,
      @pack.starter_pack_accounts.map(&:cache_key_with_version),
      accounts.map { |account| [account.cache_key_with_version, account.account_stat&.cache_key_with_version] }]
  end
end
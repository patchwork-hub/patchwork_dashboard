# frozen_string_literal: true

require 'httparty'
require 'nokogiri'

class FetchDidValueService < BaseService
  def call(account, community)
    @account = account
    @community = community
    @local_domain = ENV['LOCAL_DOMAIN']

    did_value = fetch_did_value(account_url) || fetch_did_value(community_slug_url) || fetch_did_value(community_name_url)
    did_value
  end

  private

  def account_url
    return unless @account&.username
    puts "[FetchDidValueService] url: https://fed.brid.gy/ap/@#{@account.username}@#{@local_domain}"

    "https://fed.brid.gy/ap/@#{@account.username}@#{@local_domain}"
  end

  def community_slug_url
    return unless @community&.slug
    domain = @community.is_custom_domain? ? @community.slug : "#{@community.slug}.#{@local_domain}"
    puts "[FetchDidValueService] url: https://fed.brid.gy/ap/@#{domain}"

    "https://fed.brid.gy/ap/@#{domain}"
  end

  def community_name_url
    return unless @community&.name
    puts "[FetchDidValueService] url: https://fed.brid.gy/ap/@#{@community.name}@#{@local_domain}"

    "https://fed.brid.gy/ap/@#{@community.name}@#{@local_domain}"
  end

  def fetch_did_value(url)
    return nil if url.nil?

    response = HTTParty.get(url)
    if response.code == 200
      extract_did_value(response.body)
    else
      nil
    end
  end

  def extract_did_value(response_body)
    document = Nokogiri::HTML(response_body)
    onclick_value = document.at_css("button[onclick*='writeText']")&.attr('onclick')

    if onclick_value
      did_value = onclick_value.match(/'([^']+)'/)[1]
      did_value
    else
      nil
    end
  end

end

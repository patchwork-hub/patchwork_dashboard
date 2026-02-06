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
    did_button = document.at_css("button.glyphicon-tag[onclick*='copy']")
    
    if did_button
      onclick_value = did_button.attr('onclick')
      did_match = onclick_value&.match(/copy\('(did:[^']+)'\)/)
      return did_match[1] if did_match
      
      title_value = did_button.attr('title')
      title_match = title_value&.match(/(did:\w+:\w+)/)
      return title_match[1] if title_match
    end
    nil
  end

end

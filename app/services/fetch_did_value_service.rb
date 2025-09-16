# frozen_string_literal: true

require 'httparty'
require 'nokogiri'

class FetchDidValueService < BaseService
  include ApplicationHelper

  def call(account, community)
    @account = account
    @community = community


    did_value = if is_channel_dashboard?
      [account_url, community_slug_url, community_name_url].find { |url| fetch_did_value(url) }
    else
      fetch_did_value(account_url)
    end
    did_value
  end

  private

  def account_url
    return unless @account&.username

    "https://fed.brid.gy/ap/@#{@account.username}@#{ENV['LOCAL_DOMAIN']}"
  end

  def community_slug_url
    return unless @community&.slug
    domain = @community.is_custom_domain? ? @community.slug : "#{@community.slug}.#{ENV['LOCAL_DOMAIN']}"

    "https://fed.brid.gy/ap/@#{domain}"
  end

  def community_name_url
    return unless @community&.name

    "https://fed.brid.gy/ap/@#{@community.name}@#{ENV['LOCAL_DOMAIN']}"
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

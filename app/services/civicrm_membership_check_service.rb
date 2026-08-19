# frozen_string_literal: true

require "httparty"
require "json"
require "uri"

class CivicrmMembershipCheckService
  include HTTParty

  CONTACT_GET_PATH = "/civicrm/ajax/api4/Contact/get"

  Result = Struct.new(:valid?, :error_message, :user_groups, :values_present, keyword_init: true)

  def initialize(email, working_group_id:, force_remote: false)
    @email = email
    @working_group_id = working_group_id
    @force_remote = force_remote
  end

  def call
    return valid_result unless force_remote? || feature_enabled?
    return invalid_result if @email.blank?
    return invalid_result if working_group_ids.empty?
    return valid_result if allowlisted_email? && !force_remote?
    return invalid_result unless config_present?

    response = self.class.get(endpoint_url, headers: request_headers, query: { params: request_params.to_json })
    response_body = response.respond_to?(:body) ? normalize_utf8(response.body) : ""

    unless response.success?
      Rails.logger.error("CiviCRM membership check unauthorized/failed: status=#{response.code} body=#{response_body}")
      return invalid_result
    end

    body = response.parsed_response
    body = parse_response_body(response_body) unless body.is_a?(Hash)
    return invalid_result if response_values(body).empty?

    valid_result(extract_user_groups(body), values_present: true)
  rescue StandardError => e
    Rails.logger.error("CiviCRM membership check failed: #{e.class} #{normalize_utf8(e.message)}")
    invalid_result
  end

  private

  def force_remote?
    @force_remote
  end

  def feature_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("CSID_MEMBERSHIP_CHECK_ENABLED", "false"))
  end

  def config_present?
    base_url.present? && auth_token.present?
  end

  def base_url
    raw = ENV.fetch("CIVICRM_BASE_URL", nil).to_s.strip
    return "" if raw.blank?

    candidate = raw.match?(%r{\Ahttps?://}i) ? raw : "https://#{raw}"
    uri = URI.parse(candidate)

    # Enforce HTTPS for port 443 and normalize URL without trailing slash.
    uri.scheme = "https" if uri.port == 443 || uri.scheme.blank?
    uri.to_s.chomp("/")
  rescue URI::InvalidURIError
    ""
  end

  def auth_token
    ENV.fetch("CIVICRM_AUTH_TOKEN", nil).to_s.strip.gsub(/\A'+|'+\z/, "")
  end

  def endpoint_url
    "#{base_url}#{CONTACT_GET_PATH}"
  end

  def request_headers
    {
      "accept" => "application/json, text/plain, */*",
      "x-civi-auth" => formatted_auth_token,
      "x-requested-with" => "XMLHttpRequest",
      "skipinterceptor" => "true"
    }
  end

  def formatted_auth_token
    return auth_token if auth_token.match?(/\ABearer\s+/i)

    "Bearer #{auth_token}"
  end

  def request_params
    {
      select: [
        "id",
        "contact_type",
        "display_name",
        "first_name",
        "last_name",
        "nick_name",
        "job_title",
        "current_employer",
        "image_URL",
        "email.email",
        "phone.phone",
        "address.city",
        "address.country_id:label",
        "GROUP_CONCAT(DISTINCT group_contact.group_id:label) AS user_groups",
        "GROUP_CONCAT(DISTINCT group_contact.group_id) AS user_group_ids",
        "membership.status_id:label",
        "membership.end_date",
        "Individual_Information.Bio",
        "Individual_Information.Areas_of_interest",
        "Individual_Information.Working_Group",
        "Individual_Information.Community_Role",
        "Socials.Website",
        "Socials.LinkedIn",
        "Socials.Mastodon",
        "Socials.Bluesky",
        "Socials.GitHub"
      ],
      join: [
        ["Email AS email", "LEFT", ["email.is_primary", "=", true]],
        ["Phone AS phone", "LEFT", ["phone.is_primary", "=", true]],
        ["Address AS address", "LEFT", ["address.is_primary", "=", true]],
        ["GroupContact AS group_contact", "LEFT", ["group_contact.status", "=", "'Added'"]],
        ["Membership AS membership", "LEFT", ["id", "=", "membership.contact_id"]]
      ],
      groupBy: ["id"],
      where: [
        ["is_deleted", "=", false],
        ["email.email", "=", @email],
        ["groups", "IN", working_group_ids]
      ]
    }
  end

  def working_group_ids
    Array(@working_group_id)
      .flat_map { |value| value.to_s.split(",") }
      .map { |value| value.to_s.strip }
      .reject(&:blank?)
      .filter_map { |value| Integer(value, 10) rescue nil }
      .uniq
  end

  def allowlisted_email?
    allowlisted_emails.include?(@email.to_s.strip.downcase)
  end

  def allowlisted_emails
    allowed_mails = ENV.fetch("CSID_MEMBERSHIP_ALLOWLIST_EMAILS", nil).to_s.strip
    return [] if allowed_mails.blank?

    parse_allowlisted_emails(allowed_mails)
      .map { |email| email.to_s.strip.downcase }
      .reject(&:blank?)
      .uniq
  end

  def parse_allowlisted_emails(raw_value)
    return JSON.parse(raw_value) if raw_value.start_with?("[")

    raw_value.split(/\s*,\s*/)
  rescue JSON::ParserError
    raw_value.split(/\s*,\s*/)
  end

  def parse_response_body(response_body)
    JSON.parse(response_body)
  rescue JSON::ParserError
    {}
  end

  def normalize_utf8(value)
    value
      .to_s
      .dup
      .force_encoding(Encoding::UTF_8)
      .scrub
  end

  def extract_user_groups(body)
    results = response_values(body).select { |value| value.is_a?(Hash) }
    return [] if results.empty?

    results
      .flat_map { |result| groups_from_result(result) }
      .map { |group| group.to_s.strip }
      .reject(&:blank?)
      .uniq
  end

  def groups_from_result(result)
    groups = result["user_groups"] || result[:user_groups]

    case groups
    when String
      groups.split(/[;,]/)
    when Array
      groups
    else
      []
    end
  end

  def response_values(body)
    return [] unless body.is_a?(Hash)
    return [] unless body.key?("values") || body.key?(:values)

    values = body["values"] || body[:values]
    values.is_a?(Array) ? values : []
  end

  def valid_result(user_groups = [], values_present: true)
    Result.new(valid?: true, error_message: nil, user_groups: user_groups, values_present: values_present)
  end

  def invalid_result
    Result.new(
      valid?: false,
      error_message: I18n.t("api.account.errors.membership_not_eligible", default: "Membership is not eligible for this action"),
      user_groups: [],
      values_present: false
    )
  end
end
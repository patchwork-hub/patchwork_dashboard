class DnsProviders::DnsProviderBase
  def create_or_update_txt_record(domain, name, value)
    raise NotImplementedError, "#{self.class} must implement #create_or_update_txt_record"
  end

  def before_record_operation
    # Default: no-op
  end

  def after_record_operation
    # Default: no-op
  end
end

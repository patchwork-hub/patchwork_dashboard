class CustomError < StandardError
  def initialize(msg="My custom error message")
    super
  end
end

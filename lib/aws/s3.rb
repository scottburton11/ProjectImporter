class S3 < RightAws::S3
  include Singleton
  def initialize
    super(S3_CONFIG['aws_access_key'], S3_CONFIG['aws_secret_access_key'])
  end
end
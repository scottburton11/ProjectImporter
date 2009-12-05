require 'forwardable'

require 'seamus'
gem 'uuidtools', '=1.0.7'
require 'right_aws'
require 'sdb/active_sdb'

$LOAD_PATH <<  "./lib"

require 'lib/project_importer/local_file'
require 'lib/project_importer/mover'
require 'lib/aws/s3'
require 'lib/aws/stat'

S3_CONFIG = YAML.load_file(File.dirname(__FILE__) + "/../config/s3.yml")["production"]
SDB = RightAws::ActiveSdb.establish_connection(S3_CONFIG['aws_access_key'], S3_CONFIG['aws_secret_access_key']) unless defined?(SDB)

module Seamus
  module InstanceMethods
   def content_type
      MimeTable.lookup_by_extension(extension).to_s
   end
  end
end

module ProjectImporter

  @@logger = Logger.new(STDOUT)
  @@bucket = S3_CONFIG["data_bucket_name"]
  
  def self.bucket
    @@bucket
  end
  
  def self.logger
    @@logger
  end
  
end

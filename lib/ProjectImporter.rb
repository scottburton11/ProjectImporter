require 'forwardable'

require 'seamus'
gem 'uuidtools', '=1.0.7'
require 'right_aws'
require 'sdb/active_sdb'

S3_CONFIG = YAML.load_file(File.dirname(__FILE__) + "/../config/s3.yml")["production"]

module Seamus
  module InstanceMethods
   def content_type
      MimeTable.lookup_by_extension(extension).to_s
   end
  end
end

class ProjectImporter
  
  SDB = RightAws::ActiveSdb.establish_connection(S3_CONFIG['aws_access_key'], S3_CONFIG['aws_secret_access_key']) unless defined?(SDB)
  @@logger = Logger.new(STDOUT)
  @@bucket = S3_CONFIG["data_bucket_name"]
  
  
  class LocalFile
    include Seamus
    extend Forwardable
    attr_reader :file
    
    def_delegator :@stat, :size
    def_delegator :@file, :path
    
    def initialize(path)
      @file = File.open(path)
      @stat = File.stat(path)
    end
    
    def has_thumbnail?
      case file_type
      when "video"
        true
      when "image"
        true
      else
        false
      end
    end
    
    
  end
  
  class S3 < RightAws::S3
    include Singleton
    def initialize
      super(S3_CONFIG['aws_access_key'], S3_CONFIG['aws_secret_access_key'])
    end
  end
  
  class Stat < RightAws::ActiveSdb::Base

    set_domain_name :test_stats

    def self.find_or_create_by_md5(md5)

      self.create_domain
      find_by_md5(md5) || create("md5" => md5)
    end
  end
  
  def self.move(dir, account_prefix, home)

    paths = Dir.glob("#{dir}/**/*")

    paths.each do |path|
      @importer = ProjectImporter.new(path, account_prefix, home)
      @importer.upload_to_s3
      @importer.store_attributes
      @importer.upload_thumbnail unless @importer.local_file.thumbnail.nil?
    end

    #upload the file
    #upload thumbnail if applicable
    #upload the file metadata
    #clean up if neccessary
    
  end
  
  attr_reader :local_file, :logger
  
  def initialize(path, account_prefix, home)
    @local_file = LocalFile.new(path)
    @account_prefix = account_prefix
    @home = home
    @logger = @@logger
  end
  
  def upload_to_s3
    # project.accessor.put(full_filename, {"Content-MD5" => md5_base64_encoded, "Content-Type" => content_type, "Content-Length" => size})
    # S3.store_object(:file => full_filename, :md5 => md5.to_s, :headers => {"Content-Type" => content_type, "Content-Length" => size})
    logger.info("Uploading #{local_file.file_name}, md5: #{local_file.md5.to_s}")
    S3.instance.interface.store_object(:bucket => @@bucket, :key => full_name(local_file.file_name), :md5 => local_file.md5.to_s, :data => open(local_file.path), :headers => {"Content-Type" => local_file.content_type, "Content-Length" => local_file.size, "content-disposition" => "attachment; filename=#{local_file.file_name}"})
    logger.info("#{local_file.file_name} moved to #{full_name(local_file.file_name)}")
  rescue => e
    logger.warn("Failed to copy #{local_file.file_name} - Error was #{e}")
    puts e.backtrace
  end
  
  def cleanup
    thumbnail.unlink if has_thumbnail?
    self.destroy
  end

  def store_attributes
    logger.info("Storing attributes for #{local_file.file_name}:")
    logger.info(pp local_file.file_attributes)
    begin
      stat_item = Stat.find_or_create_by_md5(local_file.md5_hex_string)
      stat_item.save_attributes(local_file.file_attributes)
    rescue => e
      logger.warn("An exception was raised: #{e}")
    end
  end

  def upload_thumbnail
    # S3.interface.put("filebox-images", "images/thumbs/#{File.basename(file_path, File.extname(file_path))}.jpg", open(thumbnail_tempfile_path))
    image = RightAws::S3::Key.create(RightAws::S3::Bucket.create(S3.instance, 'filebox-images', true), "images/thumbs/#{File.basename(local_file.file.path, File.extname(local_file.file.path)).gsub(/[\W]+/i,"_")}.jpg")
    headers = {"content-type" => "image/jpeg"}
    image.meta_headers = {"x-amz-meta-thumbnail-for" => File.basename(local_file.file.path)}
    # temp_thumbnail = File.open(thumbnail.path)
    image.put(local_file.thumbnail.open, 'public-read', headers)
  end
  
  private

  def full_name(name)
    [@account_prefix, @home, name].join("/")
  end  
  
end

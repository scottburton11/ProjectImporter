module ProjectImporter
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
end
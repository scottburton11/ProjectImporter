class Stat < RightAws::ActiveSdb::Base

  set_domain_name :test_stats

  def self.find_or_create_by_md5(md5)

    self.create_domain
    find_by_md5(md5) || create("md5" => md5)
  end
end
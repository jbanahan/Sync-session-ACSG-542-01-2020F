module OpenChain::DelayedJobExtensions
  def self.get_class dj
    h = dj.handler.split("\n")[1]
    return h if h =~ /object: !ruby\/ActiveRecord\:/
    raise "Unexpected format in Delayed::Job handler field!"
  end

  def self.group_jobs
    by_class = Hash.new {|k,v| k[v] = []}
    error_jobs = Delayed::Job.where("last_error IS NOT NULL")
    error_jobs.each do |job|
      klass = get_class job
      by_class[klass] << job.id
    end
    by_dj_id = {}
    by_class.each do |klass, dj_id_list|
      dj_id_list.each { |dj_id| by_dj_id[dj_id] = by_class[klass] }
    end
    by_dj_id
  end
end

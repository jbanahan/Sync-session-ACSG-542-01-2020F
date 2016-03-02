module OpenChain::DelayedJobExtensions
  def self.get_class dj
    h = dj.handler.to_s.split("\n")[1]
    return h if h =~ /object: !ruby\/ActiveRecord\:/
  end

  def self.group_jobs
    by_class = Hash.new {|k,v| k[v] = []}
    error_jobs = Delayed::Job.where("last_error IS NOT NULL AND locked_at IS NULL")
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

module OpenChain; module BulkAction; class BulkComment
  def self.act user, id, opts
    commentable = CoreModule.find_by_class_name(opts['module_type']).klass.find(id)
    if commentable.can_comment?(user)
      subj = opts['subject']
      body = opts['body']
      commentable.comments.create!(subject:subj,body:body,user:user)
    else
      raise "User cannot create comments for #{opts['module_type']} id #{id}."
    end
  end
end; end; end

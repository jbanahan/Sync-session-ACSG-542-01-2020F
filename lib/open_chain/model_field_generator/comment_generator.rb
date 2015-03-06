module OpenChain; module ModelFieldGenerator; module CommentGenerator
  def make_comment_arrays(rank_start,uid_prefix,klass)
    [
      [rank_start,"#{uid_prefix}_comment_count".to_sym,:comment_count,"Comment Count",{
        data_type: :integer,
        history_ignore: true,
        read_only: true,
        import_lambda: lambda {|o,d| "Comment count is read only."},
        export_lambda: lambda {|o| o.comments.size},
        qualified_field_name: "(SELECT count(id) FROM comments WHERE commentable_id = #{klass.tableize}.id AND commentable_type = '#{klass}')"
        }]
    ]
  end
end; end; end

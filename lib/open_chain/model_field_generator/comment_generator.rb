module OpenChain; module ModelFieldGenerator; module CommentGenerator
  def make_comment_arrays(rank_start,uid_prefix,klass)
    [
      [
        rank_start,"#{uid_prefix}_comment_count".to_sym,:comment_count,"Comment Count",{
          data_type: :integer,
          history_ignore: true,
          read_only: true,
          import_lambda: lambda {|o,d| "Comment count is read only."},
          export_lambda: lambda {|o| o.comments.size},
          qualified_field_name: "IFNULL((SELECT count(id) FROM comments WHERE commentable_id = #{klass.tableize}.id AND commentable_type = '#{klass}'),0)"
          }
      ],
      [
        rank_start+1,"#{uid_prefix}_last_comment_body".to_sym,:last_comment_body,"Last Comment Body", {
          data_type: :string,
          history_ignore: true,
          read_only: true,
          export_lambda: lambda {|o| c = o.comments.order('comments.created_at DESC, comments.id DESC').first; c.nil? ? '' : c.body},
          qualified_field_name: "IFNULL((SELECT body FROM comments WHERE commentable_id = #{klass.tableize}.id AND commentable_type = '#{klass}' ORDER BY comments.created_at DESC, comments.id DESC LIMIT 1),'')"
        }
      ],
      [
        rank_start+2,"#{uid_prefix}_last_comment_by".to_sym,:last_comment_by,"Last Comment By", {
          data_type: :string,
          history_ignore: true,
          read_only: true,
          export_lambda: lambda {|o| c = o.comments.order('comments.created_at DESC, comments.id DESC').first; c.nil? ? '' : c.user.username},
          qualified_field_name: "IFNULL((SELECT users.username FROM comments INNER JOIN users ON comments.user_id = users.id WHERE commentable_id = #{klass.tableize}.id AND commentable_type = '#{klass}' ORDER BY comments.created_at DESC, comments.id DESC LIMIT 1),'')"
        }
      ],
      [
        rank_start+3,"#{uid_prefix}_last_comment_at".to_sym,:last_comment_at,"Last Comment Date", {
          data_type: :datetime,
          history_ignore: true,
          read_only: true,
          export_lambda: lambda {|o| c = o.comments.order('comments.created_at DESC, comments.id DESC').first; c.nil? ? nil : c.created_at},
          qualified_field_name: "IFNULL((SELECT comments.created_at FROM comments WHERE commentable_id = #{klass.tableize}.id AND commentable_type = '#{klass}' ORDER BY comments.created_at DESC, comments.id DESC LIMIT 1),'')"
        }
      ],
      [
        rank_start+4,"#{uid_prefix}_last_comment_subject".to_sym,:last_comment_subject,"Last Comment Subject", {
          data_type: :string,
          history_ignore: true,
          read_only: true,
          export_lambda: lambda {|o| c = o.comments.order('comments.created_at DESC, comments.id DESC').first; c.nil? ? '' : c.subject},
          qualified_field_name: "IFNULL((SELECT subject FROM comments WHERE commentable_id = #{klass.tableize}.id AND commentable_type = '#{klass}' ORDER BY comments.created_at DESC, comments.id DESC LIMIT 1),'')"
        }
      ]

    ]
  end
end; end; end

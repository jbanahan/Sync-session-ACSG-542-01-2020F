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
      ],
      [rank_start+5, "#{uid_prefix}_comment_last_7_days".to_sym, :comment_last_7_days, "Comments - Last 7 Days", :data_type=>:string, :read_only=>true, :history_ignore=>true,
        :import_lambda => lambda {|a,b| return "Comments - Last 7 Days cannot be set by import, ignored."},
        :export_lambda => lambda {|obj| Comment.gather(obj, DateTime.now - 7.days)},
        :qualified_field_name => %Q((SELECT GROUP_CONCAT(CONCAT(DATE_FORMAT(CONVERT_TZ(c7.updated_at, 'UTC', '#{Time.zone.tzinfo.name}'),'%m-%d %H:%i')," ",IF(c7.subject IS NULL OR c7.subject = "","",CONCAT(c7.subject,": ")),IFNULL(c7.body,"")) ORDER BY c7.updated_at DESC SEPARATOR "\n \n") FROM comments c7 WHERE c7.commentable_id = #{klass.tableize}.id AND c7.commentable_type = '#{klass}' AND DATE_SUB(NOW(), INTERVAL 7 DAY) <= c7.updated_at))
      ],
      [rank_start+6, "#{uid_prefix}_comment_last_24_hrs".to_sym, :comment_last_2_hrs, "Comments - Last 24 Hours", :data_type=>:string, :read_only=>true, :history_ignore=>true,
        :import_lambda => lambda {|a,b| return "Comments - Last 24 Hours cannot be set by import, ignored."},
        :export_lambda => lambda {|obj| Comment.gather(obj, DateTime.now - 24.hours)},
        :qualified_field_name => %Q((SELECT GROUP_CONCAT(CONCAT(DATE_FORMAT(CONVERT_TZ(c24.updated_at, 'UTC', '#{Time.zone.tzinfo.name}'),'%m-%d %H:%i')," ",IF(c24.subject IS NULL OR c24.subject = "","",CONCAT(c24.subject,": ")),IFNULL(c24.body,"")) ORDER BY c24.updated_at DESC SEPARATOR "\n \n") FROM comments c24 WHERE c24.commentable_id = #{klass.tableize}.id AND c24.commentable_type = '#{klass}' AND DATE_SUB(NOW(), INTERVAL 24 DAY_HOUR) <= c24.updated_at))
      ],
      [rank_start+7, "#{uid_prefix}_comment_last_25".to_sym, :comment_last_25, "Comments - Last 25", :data_type=>:string, :read_only=>true, :history_ignore=>true,
        :import_lambda => lambda {|a,b| return "Comments - Last 25 cannot be set by import, ignored."},
        :export_lambda => lambda {|obj| Comment.gather(obj, nil, 25)},
        :qualified_field_name => %Q((SELECT GROUP_CONCAT(CONCAT(DATE_FORMAT(CONVERT_TZ(c25.updated_at, 'UTC', '#{Time.zone.tzinfo.name}'),'%m-%d %H:%i')," ",IF(c25.subject IS NULL OR c25.subject = "","",CONCAT(c25.subject,": ")),IFNULL(c25.body,"")) ORDER BY c25.updated_at DESC SEPARATOR "\n \n") FROM comments c25 WHERE c25.commentable_id = #{klass.tableize}.id AND c25.commentable_type = '#{klass}' LIMIT 25))
      ]

    ]
  end
end; end; end

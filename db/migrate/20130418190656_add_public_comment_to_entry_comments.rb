class AddPublicCommentToEntryComments < ActiveRecord::Migration

  def up 
    add_column :entry_comments, :public_comment, :boolean
    query = <<-SQL
      UPDATE entry_comments SET public_comment = 1 
      WHERE
      (
            (UPPER(body) NOT REGEXP '^DOCUMENT IMAGE CREATED FOR')
        AND (UPPER(body) NOT REGEXP '^CUSTOMER HAS BEEN CHANGED FROM')
        AND (UPPER(body) NOT REGEXP '^E/S QUERY RECEIVED - ENTRY SUMMARY DATE UPDATED')
        AND (UPPER(body) NOT REGEXP '^ENTRY SUMMARY DATE QUERY SENT')
        AND (UPPER(body) NOT REGEXP '^PAY DUE NOT CHANGED, SAME PAY DUE DATE')
        AND (UPPER(body) NOT REGEXP '^PAYMENT TYPE CHANGED')
        AND (UPPER(body) NOT REGEXP '^STMNT DATA REPLACED AS REQUESTED')
        AND (UPPER(body) NOT REGEXP '^STMNT.*AUTHORIZED')
      )
    SQL
    execute query
    execute "UPDATE entry_comments SET public_comment = 0 WHERE public_comment IS NULL"
  end

  def down
    remove_column :entry_comments, :public_comment
  end
end

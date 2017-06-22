module OpenChain; module CustomHandler; module UnderArmour; module UnderArmourBusinessLogic

  def article_number sku
    sku =~ /\A([^\-]+-[^\-]+)-[^\-]+\z/ ? $1 : sku
  end

  def prepack_article_number sku
    sku =~ /\A([^\-]+)-[^\-]+-[^\-]+\z/ ? $1 : sku
  end

end; end; end; end;
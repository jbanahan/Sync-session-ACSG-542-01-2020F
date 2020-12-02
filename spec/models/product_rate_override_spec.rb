describe ProductRateOverride do
  context 'security' do
    describe '#can_view?' do
      it 'should defer to product.can_view?' do
        u = double('user')
        p = Product.new
        expect(p).to receive(:can_view?).with(u).and_return 'view'
        expect(ProductRateOverride.new(product:p).can_view?(u)).to eq 'view'
      end
    end
    describe '#can_edit?' do
      it 'should defer to product.can_classify?' do
        u = double('user')
        p = Product.new
        expect(p).to receive(:can_classify?).with(u).and_return 'cs'
        expect(ProductRateOverride.new(product:p).can_edit?(u)).to eq 'cs'
      end
    end
    describe '#search_secure' do
      it 'should wrap to product.search_where' do
        u = double('user')
        expect(Product).to receive(:search_where).with(u).and_return '99=99'
        pro = create(:product_rate_override)
        search = ProductRateOverride.search_secure(u, ProductRateOverride)
        expect(search.to_sql).to match(/product_rate_overrides\.product_id IN \(SELECT products\.id FROM products WHERE 99=99\)/)
        expect(search.to_a).to eq [pro]
      end
    end
  end
end

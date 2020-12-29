@pa = angular.module('ProductApp').directive 'productClassification', [ 'productSvc', (productSvc) ->
  {
    restrict: 'E'
    scope: {
      product: '='
      importCountries: '='
      dictionary: '='
    }
    templateUrl: '/partials/products/product_classification.html'
    link: (scope,el,attrs) ->
      scope.productSvc = productSvc
      scope.addTariff = (cls) ->
        max = 0

        for tr in cls.tariff_records
          max = tr.hts_line_number if tr.hts_line_number && tr.hts_line_number > max

        cls.tariff_records = [] unless cls.tariff_records
        cls.tariff_records.push({hts_line_number:max+1})

      scope.activateClassification = (country, product) ->
        cls = productSvc.classificationByISO(country.iso_code,product)

        if cls==null
          cls = {class_cntry_iso:country.iso_code,class_cntry_name:country.name,tariff_records:[]}
          scope.addTariff(cls)
          product.classifications = [] unless product.classifications
          product.classifications.push(cls)

        scope.activeClassification=cls

      scope.canAutoClassify = (tr) ->
        tr.hts_line_number && tr.hts_hts_1 && tr.hts_hts_1.replace(/[^\d]/g,'').length >= 6

      scope.autoClassify = (p,tr) ->
        productSvc.autoClassify(p,tr)

      scope.sameHts = (hts1,hts2) ->
        if hts1 == hts2
          return true
        if hts1 && hts2 && hts1.replace(/[^\d]/g,'')==hts2.replace(/[^\d]/g,'')
          return true

        return false


      scope.$on 'chain:view-edit:open', ->
        scope.activeClassification = null
  }
]

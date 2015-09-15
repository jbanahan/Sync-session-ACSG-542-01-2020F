@pa = angular.module('ProductApp')
@pa.filter('productComponentEditFields', ->
  (dictionary,country_iso) ->
    return [] unless dictionary
    r = []
    #always show hts_1 as first field
    r.push(dictionary.fields.hts_hts_1)
    fields = dictionary.fieldsByRecordType(dictionary.recordTypes.TariffRecord)
    otherFields = $.grep(fields, (fld) ->
      # don't show legacy hts 2 & 3 fields (or schedule b equivalents)
      for regex in [/hts_[23]$/,/[23]_schedb$/,/^hts_hts_1$/,/hts_line_number/,/hts_view_sequence/]
        return null if fld.uid.match(regex)

      # only return schedule b for US
      return null if !country_iso || country_iso.toLowerCase()!='us' && fld.uid=='hts_hts_1_schedb'

      # don't show hts_hts_1 since we're hard coding it to be first in the list
      return fld
    )
    r.concat otherFields
)
@pa.directive 'productClassification', [ 'productSvc', (productSvc) ->
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
          product.classifications.push(cls)

        scope.activeClassification=cls
  }
]
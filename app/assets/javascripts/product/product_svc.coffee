angular.module('ProductApp').factory 'productSvc', ['$http','$q','officialTariffSvc','commentSvc',($http,$q,officialTariffSvc,commentSvc) ->
  currentProduct = undefined
  productLoadSuccessHandler = (resp) ->
    # remove unwanted field
    delete resp.data.product.prod_ent_type_id

    #handle the response then pass it along in the chain
    currentProduct = resp.data.product
    resp

  return {
    getProduct: (id) ->
      deferred = $q.defer()

      if currentProduct && parseInt(currentProduct.id) == parseInt(id)
        #simulate the http response with the cached object
        deferred.resolve {data: {product: currentProduct}}
      else
        $http.get('/api/v1/products/'+id+'.json?include=attachments').then(productLoadSuccessHandler).then (resp) ->
          commentSvc.injectComments(currentProduct,'Product')
          deferred.resolve {data: {product: currentProduct}}

      deferred.promise

    saveProduct: (prod) ->
      currentProduct = null
      method = 'post'
      suffix = '.json'

      if prod.id > 0
        method = 'put'
        suffix = "/#{prod.id}.json"

      $http[method]("/api/v1/products"+suffix,{product:prod, include: 'attachments'}).then(productLoadSuccessHandler)
      
    classificationByISO: (iso,product) ->
      return null unless product && product.classifications
      for cls in product.classifications
        cci = cls.class_cntry_iso
        cci = '' unless cci
        return cls if cci.toLowerCase() == iso.toLowerCase()
      return null

    autoClassify: (product,tariffRecord) ->
      targetLine = tariffRecord.hts_line_number
      baseHts = tariffRecord.hts_hts_1

      unless targetLine
        throw new Error("Cannot autoClassify without hts_line_number.")

      unless baseHts && baseHts.replace(/[^\d]/,'').length >= 6
        throw new Error("Cannot autoClassify without a minimum 6 digit HTS.")

      product.autoClassifying = true
      officialTariffSvc.autoClassify(baseHts).then (otResp) ->
        for cls in product.classifications
          iso = cls.class_cntry_iso
          otHts = otResp[iso]
          if otHts
            cls.tariff_records = [] unless cls.tariff_records

            foundTariffRecord = null
            for tr in cls.tariff_records
              foundTariffRecord = tr if tr.hts_line_number == targetLine

            if !foundTariffRecord
              foundTariffRecord = {hts_line_number:targetLine}
              cls.tariff_records.push(foundTariffRecord)

            foundTariffRecord.autoClassifications = otHts.hts
        product.autoClassifying = false
  }
]
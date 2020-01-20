module ConfigMigrations; module Www; class EdiChangesForQtyAndSku1829

  def up
    populate_omu_data
    generate_data_cross_references
    nil
  end

  def down
    UnitOfMeasure.destroy_all
    drop_data_cross_references
    nil
  end

  private
    def populate_omu_data
      UnitOfMeasure.where(system: 'Customs Management', uom: 'AE', description: 'Aerosol').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'AM', description: 'Ampoule, Non-Protected').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'AMM', description: 'Ammo Pack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'AP', description: 'Ampoule, Protected').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'AT', description: 'Atomizer').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BA', description: 'Barrel').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BAG', description: 'Bag').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BAL', description: 'Bal').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BALE', description: 'Bale, Compressed').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BAR', description: 'Bar').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BASKET', description: 'Basket').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BB', description: 'Bobbin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BBL', description: 'Barrels').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BC', description: 'Bottlecrate, Bottlerack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BD', description: 'Board').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BDL', description: 'Bundle').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BE', description: 'Bundle').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BEM', description: 'Beam').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BF', description: 'Ballon, Non-Protected').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BG', description: 'Bag').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BH', description: 'Bunch').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BI', description: 'Bin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BIC', description: 'Bing Chest').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BIN', description: 'Bin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BJ', description: 'Bucket').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BK', description: 'Basket').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BKG', description: 'Bulk Bag').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BKT', description: 'Bucket').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BL', description: 'Bale, Compressed').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BLE', description: 'Bale').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BLK', description: 'Bulk').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BN', description: 'Bale, Non-Compressed').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BO', description: 'Bottle, Non-Protected, Cyl').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BOARD', description: 'Board').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BOB', description: 'Bobbin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BOL', description: 'Boluses (Dosage)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BOLT', description: '  Bolt').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BOT', description: 'Bottle').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BOTTLE', description: 'Bottles').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BOX', description: 'Box').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BP', description: 'Ballon, Protected').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BQ', description: 'Ballon, Protected, Cylnd').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BR', description: 'Bar').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BRG', description: 'Barge').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BS', description: 'Bottle, Non-Protected, Bulbous').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BSK', description: 'Basket').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BT', description: 'Bolt').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BU', description: 'Butt').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BUCKET', description: 'Bucket').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BUNCH', description: 'Bunch').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BUNDLE', description: 'Bundle').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BUTT', description: 'Butt').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BV', description: 'Bottle, Protected, Bulbous').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BX', description: 'Box').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BXI', description: 'Box with inner container').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BXT', description: 'Bucket').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BY', description: 'Board in Bundle/Bunch/Truss').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'BZ', description: 'Bars in Bundle/Bunch/Truss').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'C', description: 'Celsius').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'C3', description: 'Cubic centimeters').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CA', description: 'Can, Rectangular').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CAB', description: 'Cabinet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CAG', description: 'Cage').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CAGE', description: 'Cage').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CAN', description: 'Can, Rectangular').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CAP', description: 'Capsules (Dosage)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CAR', description: 'Carats (Weight)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CARTON', description: 'Carton').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CAS', description: 'Case').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CASE', description: 'Case').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CASES', description: 'Cases').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CB', description: 'Crate, Beer').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CBC', description: 'Container Bulk Cargo').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CBY', description: 'Carboy').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CC', description: 'Churn').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CCS', description: 'Can Case').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CE', description: 'Creel').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CF', description: 'Coffer').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CFT', description: 'Cubic Feet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CG', description: 'Centigrams').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CGM', description: 'Content Gram').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CH', description: 'Chest').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CHE', description: 'Cheeses').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CHS', description: 'Chest').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CI', description: 'Canister').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CJ', description: 'Coffin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CK', description: 'Cask').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CKG', description: 'Content Kilogram').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CL', description: 'Coil').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CLD', description: 'Car Load, Rail').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CM', description: 'Centimeter').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CM3', description: 'Cubic Centimeters').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CNB', description: 'Container MSC ISO Military Airlift').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CNC', description: 'Container, Navy Cargo Transporter').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CND', description: 'Container, Commercial Highway lift').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CNE', description: 'Engine Container').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CNF', description: 'Multiwall Container Warehs Pallet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CNT', description: 'Container (Not used in Sea AMS)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CNX', description: 'CONEX   Container Express').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CO', description: 'Carboy, Non-Protected').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'COILS', description: 'Coils').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'COL', description: 'Coil').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CON', description: 'Container').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'COR', description: 'Cord').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CP', description: 'Carboy, Protected').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CR', description: 'Crate').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CRATE', description: 'Crate').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CRD', description: 'Cradle').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CRT', description: 'Crate').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CS', description: 'Cases').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CSK', description: 'Cask').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CT', description: 'Carton').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CTN', description: 'Content Ton').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CTNS', description: 'Cartons').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CU', description: 'Cup').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CUB', description: 'Cube').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CV', description: 'Cover').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CX', description: 'Can, Cylindrical').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CY', description: 'Cylinder').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CYD', description: 'Cubic Yards').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CYG', description: 'Clean Yield Gram').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CYK', description: 'Clean Yield Kilogram').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CYL', description: 'Cylinder').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'CZ', description: 'Canvas').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DBK', description: 'Dry Bulk').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DEG', description: 'Degrees').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DJ', description: 'Demijohm, Non-Protected').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DOZ', description: 'Dozens').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DP', description: 'Demijohm, Protected').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DPC', description: 'Dozen Pieces').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DPR', description: 'Dozen Pairs').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DR', description: 'Drum').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DRK', description: 'Double Length Rack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DRM', description: 'Drum').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DRMS', description: 'Drums').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DSK', description: 'Double Length Skid').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DTB', description: 'Double Length Toe Bin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'DUF', description: 'Duffel Bag').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'EACH', description: 'Each').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'EN', description: 'Envelope').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'ENV', description: 'Envelope').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FBM', description: 'Fiber M').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FC', description: 'Crate, Fruit').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FD', description: 'Crate, Framed').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FI', description: 'Firkin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FIB', description: 'Fiber').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FIR', description: 'Firkin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FL', description: 'Flask').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FLO', description: 'Flo bin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FLX', description: 'Liner Bag Liquid').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FO', description: 'Footlocker').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FOZ', description: 'Ounces, (Fluid)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FP', description: 'Flimpack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FR', description: 'Frame').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FRM', description: 'Frame').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FSK', description: 'Flask').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FT3', description: 'Cubic Feet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'FWR', description: 'Forward').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'G', description: 'Gram').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'GAL', description: 'Gallons').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'GB', description: 'Bottle, Gas').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'GI', description: 'Girders').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'GM', description: 'Grams').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'GOH', description: 'Garments on Hangers').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'GR', description: 'Gross').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'GRL', description: 'Gross Lines').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'GZ', description: 'Girders in Bundle/Bunch/Truss').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'HED', description: 'Heads of Beef').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'HG', description: 'Hogshead').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'HGH', description: 'Hogshead').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'HMP', description: 'Hamper').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'HPT', description: 'Hopper Truck').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'HR', description: 'Hamper').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'HRB', description: 'On Hanger or Rack in Boxes').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'HRK', description: 'Half Standard Rack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'HTB', description: 'Half Standard Tote Bin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'HUN', description: 'Hundreds').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'HZ', description: 'Hertz').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'IN', description: 'Inch').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'IZ', description: 'Ingots in Bundle/Bunch/Truss').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'JAR', description: 'Jar').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'JC', description: 'Jerrican, Rectangular').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'JG', description: 'Jug').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'JR', description: 'Jar').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'JT', description: 'Jutebag').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'JUG', description: 'Jug').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'JWL', description: 'Number of Jewels').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'JY', description: 'Jerrican, Cylindrical').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'K', description: '1,000').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KEG', description: 'Keg').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KG', description: '1,000 Grams').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KHZ', description: 'Kilohertz').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KIT', description: 'Kit').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KM', description: '1,000 Meters').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KM2', description: '1,000 Square Meters').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KM3', description: '1,000 Cubic Meters').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KN', description: 'Kilonewton').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KPA', description: 'Kilopascal').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KRK', description: 'Knockdown Rack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KSB', description: '1,000 Standard Brick').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KTB', description: 'Knockdown Tote Bin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KW ', description: 'Kilowatts').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KWH', description: 'Kilowatt-Hours').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'L', description: 'Liter').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'LB', description: 'Pounds').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'LBK', description: 'Liquid Bulk').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'LG', description: 'Log').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'LIF', description: 'Lifts').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'LIN', description: 'Linear').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'LNM', description: 'Linear Meters').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'LOG', description: 'Logs').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'LSE', description: 'Loose').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'LT', description: 'Liters').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'LUG', description: 'Lugs').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'LVN', description: 'Lift Van').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'LZ', description: 'Logs in Bundle/Bunch/Truss').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'M', description: 'Meters').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'M2', description: 'Square Meters').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'M3', description: 'Cubic Meters').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'MB', description: 'Bag, Multi_ply').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'MBQ', description: 'Megabecquerel').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'MC', description: 'Crate, Milk').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'MG', description: 'Milligram').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'ML', description: 'Milliliter').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'MLV', description: 'MILVAN   Military Van').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'MPA', description: 'Megapascal').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'MRP', description: 'Multi Roll Pack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'MS', description: 'Sack, Multiwall').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'MSV', description: 'MSCVAN Military Sealift Command Van').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'MT', description: 'Mat (FDA,NCAP), Meters (FWS)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'MX', description: 'Matchbox').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'MXD', description: 'Mixed Type Pack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'NE', description: 'Unpacked or Unpackaged').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'NO', description: 'Number').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'NOL', description: 'Noil').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'NS', description: 'Nest').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'NT', description: 'Net').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'OVW', description: 'Overwrap').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'OZ', description: 'Ounces, (Weight)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PA', description: 'Packet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PAL', description: 'Pallet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PALLET', description: 'Pallet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PC', description: 'Parcel').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PCK', description: 'Packed   not otherwise specified').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PCL', description: 'Parcel').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PCS', description: 'Pieces').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PFG', description: 'Proof Gallon').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PFL', description: 'Proof Liter').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PG', description: 'Plate').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PH', description: 'Pitcher').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PI', description: 'Pipe').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PIR', description: 'Pims').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PK', description: 'Package').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PKG', description: 'Package').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PKGS', description: 'Packages').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PL', description: 'Pail').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PLF', description: 'Platform').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PLN', description: 'Pipeline').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PLT', description: 'Pallet (Not used in Sea AMS)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PN', description: 'Plank').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PO', description: 'Pouch').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'POV', description: 'Private Vehicle').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PRK', description: 'Pipe Rack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PRS', description: 'Pairs').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PT', description: 'Pot').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PTL', description: 'Pints,').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PU', description: 'Tray or Tray Pack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PY', description: 'Plates, in Bundles/Bunch/Truss').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'PZ', description: 'Planks or Pipes, Bundle/Bunch').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'QTL', description: 'Quarts').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'QTR', description: 'Quarters of Beef').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'RAL', description: 'Rail (Semiconductor)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'RCK', description: 'Rack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'RD', description: 'Rod').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'REEL', description: 'Reel').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'REL', description: 'Reel').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'RG', description: 'Ring').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'RL', description: 'Reel').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'RO', description: 'Roll').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'ROD', description: 'Rod').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'ROL', description: 'Roll').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'ROLL', description: 'ROLL').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'RT', description: 'Rednet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'RVR', description: 'Reverse Reel').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'RZ', description: 'Rods in Bundles/Bunch/truss').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SA', description: 'Sack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SAK', description: 'Sack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SBC', description: 'Liner Bag Dry').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SBE', description: 'Stnd Brick Equivalent').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SC', description: 'Crate, Shallow').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SCS', description: 'Suitcase').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SD', description: 'Spindle').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'S', description: 'Sea-chest').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SFT', description: 'Sq. Feet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SH', description: 'Sachet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SHEET', description: 'Sheet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SHK', description: 'Shook').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SHT', description: 'Sheet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SID', description: 'Sides of Beef').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SK', description: 'Case, Skeleton').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SKD', description: 'Skid').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SKE', description: 'Skid elevating or lift truck').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SL', description: 'Slipsheet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SLP', description: 'Slip Sheet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SLV', description: 'Sleeve').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SM', description: 'Sheetmetal').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SPI', description: 'Sin Cylinders').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SPL', description: 'Spool').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SQ', description: 'Square').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SQI', description: 'Sq. Inches').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'ST', description: 'Sheet').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'STN', description: 'Short Ton, (2000 LB)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SU', description: 'Suitcase').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SUP', description: 'Suppositories (Dosage)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SVN', description: 'SEAVAN   Sea Van').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SW', description: 'Shrinkwrapped').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SYD', description: 'Sq. Yards').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'SZ', description: 'Sheets in Bundle/Bunch/Truss').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'T', description: 'Metric Ton').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TAB', description: 'Tablets (Dosage)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TANK', description: 'Tank').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TB', description: 'Tub').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TBE', description: 'Tube').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TBN', description: 'Tote Bin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TC', description: 'Tea-chest').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TD', description: 'Tube, Collapsible').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TIN', description: 'Tin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TK', description: 'Tank, Rectangular').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TKR', description: 'Tank Car').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TKT', description: 'Tank Truck').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TLD', description: 'Intermodal Train/Container Load').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TN', description: 'Tin').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TNK', description: 'Tank').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TO', description: 'Tun').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TON', description: 'Long Ton, (2240 LB)').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TOZ', description: 'Ounces, Troy or Apoth').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TR', description: 'Trunk').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TRC', description: 'Tierce').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TRI', description: 'Triwall Box').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TRK', description: 'Trunk or Chest').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TRY', description: 'Tray').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TS', description: 'Truss').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TSS', description: 'Trunk, Salesmen Sample').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TTC', description: 'Tote Can').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TU', description: 'Tube').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TUB', description: 'Tub').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TY', description: 'Tank, Cylindrical').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'TZ', description: 'Tubes in Bundle/Bunch/Truss').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'UNP', description: 'Unpacked').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'UNT', description: 'Unit').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'VA', description: 'Vat').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'VEH', description: 'Vehicles').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'VG', description: 'Bulk Gas at 1031 MBAR').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'VI', description: 'Vial').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'VL', description: 'Bulk Liquid').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'VO', description: 'Bulk, Solid, Lg Particles').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'VP', description: 'Vacuum-Packaged').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'VPK', description: 'Van Pack').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'VQ', description: 'Bulk Liquified Gas').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'VR', description: 'Bulk, Solid, Granular Particles').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'VY', description: 'Bulk, Solid, Fine Particles').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'WB', description: 'Wickerbottle').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'WDC', description: 'Wooden Case').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'WHE', description: 'On Own Wheels').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'WLC', description: 'Wheeled Carrier').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'WRP', description: 'Wrapped').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'X', description: 'NONE').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'YD', description: 'Yards').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'YD3', description: 'Cubic Yards').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'ING', description: 'Ingot').first_or_create!
      UnitOfMeasure.where(system: 'Customs Management', uom: 'KGS', description: 'Kilograms').first_or_create!
    end

    def generate_data_cross_references
      if Company.with_customs_management_number("THEROC").first
            DataCrossReference.where(cross_reference_type: DataCrossReference::UNIT_OF_MEASURE, key:'PR', value:'PRS', company: Company.with_customs_management_number("THEROC").first).first_or_create!
      end
    end

    def drop_data_cross_references
      DataCrossReference.where(cross_reference_type: DataCrossReference::UNIT_OF_MEASURE).destroy_all
    end

end; end; end

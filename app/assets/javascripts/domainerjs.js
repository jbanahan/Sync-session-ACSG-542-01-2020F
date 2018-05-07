/* jshint -W032 */
function Domainer(domainDataAccessSetup) {
  this.das = domainDataAccessSetup;

  // standard method
  this.withDictionary = function(worker) {
    this.das.expirationChecker.checkExpiration(this,worker);
  };

  // bypass the expiration check and only use the local copy
  this.withLocalDictionary = function(worker) {
    this.das.localDAO.makeDictionary(worker);
  };

  // bypass the expiration check and only use the remote copy
  this.withRemoteDictionary = function(worker) {
    var f = worker;

    // if the localDAO has a writeDictionary method, pass the dictionary to it so it's
    // written to the cache
    if(this.das.localDAO && this.das.localDAO.writeDictionary!==undefined) {
      var domainer = this;
      f = function(dict) {
        domainer.das.localDAO.writeDictionary(dict);
        worker(dict);
      };
    }
    this.das.remoteDAO.makeDictionary(f);
  };
}
;
// simplest Domain DAO Implementation
// just takes a dictionary that you define somewhere else and passes it through to the worker
function DomainDAOPassthrough(dictionary) {
  this.dictionary = dictionary;
  this.makeDictionary = function(workerFunc) {
    workerFunc(this.dictionary);
  };
};
// holds the objects that the DomainLoader needs to have injected so they can be passed around as one setup unit
function DomainDataAccessSetup(localDAO, remoteDAO, expirationChecker) {
  this.localDAO = localDAO;
  this.remoteDAO = remoteDAO;
  this.expirationChecker = expirationChecker;
};
function DomainDictionary() {
  this.recordTypes = {};
  this.fields = {};
  this.logClobbers = false

  this.setLogClobbers = function(onOff) {
    this.logClobbers = onOff
  }

  // get a specific record type by UID
  this.recordType = function(uid) {
    return this.recordTypes[uid];
  };

  // get a specific field by UID
  this.field = function(uid) {
    return this.fields[uid];
  };

  //do not call, use other registerMethods
  this.registerSomething = function(obj, dataContainer, name, alternateUid) {
    var uid = null;
    if (alternateUid) {
      uid = alternateUid
    } else {
      uid = obj.uid;
      if(!uid) {
        throw new Error(name+" must have uid property.");
      }
    }
    if (this.logClobbers) {
      var oldObj = dataContainer[uid];

      if(oldObj && oldObj!==obj) {
        console.log("WARNING: Replacing "+name+" \""+uid+"\" with a new object.");
      }
    }
    dataContainer[uid] = obj;
  };

  // add a record type
  this.registerRecordType = function(recordType) {
    this.registerSomething(recordType,this.recordTypes,"RecordType");
  };

  // add a field (uid is optional, you can use it to associated the same field object with multiple uid keys)
  this.registerField = function(field, uid) {
    if(!field.recordType) {
      throw new Error("Field must have recordType property.");
    }
    if(!this.recordType(field.recordType.uid)) {
      throw new Error("Field's recordType ("+field.recordType.uid+") is not registered.");
    }
    this.registerSomething(field,this.fields,"Field",uid);
  };

  // get array of all fields for a record type or string representing recordType.uid
  // returns an array that is unlinked from the internals of the object, so you can manipulate it
  this.fieldsByRecordType = function(recordType,sortFunction) {
    var dataArray = [], dataObject = this.fields; rt = null;
    if(recordType.uid) {
      rt = recordType;
    } else {
      rt = this.recordTypes[recordType];
    }
    for(var o in dataObject) {
      if(dataObject.hasOwnProperty(o) && dataObject[o].recordType===rt) {
        dataArray.push(dataObject[o]);
      }
    }
    if(sortFunction) {
      dataArray.sort(sortFunction);
    }
    return dataArray;
  };

  // get array of all fields that match an attribute and value
  // optional 3rd parameter takes a list of fields to search instead of full internal list
  // returns an array that is unlinked from the internals of the object, so you can manipulate it
  this.fieldsByAttribute = function(attribute, value, fieldList) {
    var dataArray = [];
    var dataObject = fieldList ? fieldList : this.fields;
    for(var o in dataObject) {
      fld = dataObject[o];
      if(fld[attribute]==value) {
        dataArray.push(fld);
      }
    }
    return dataArray;
  };


}
;
function DomainExpirationCheckerLocal() {
  this.checkExpiration = function(domainer,worker) {
    domainer.withLocalDictionary(worker);
  };
};
// DomainExpirationChecker that expires every X seconds
function DomainExpirationCheckerTimer(seconds) {
  this.expirationPeriod = seconds;
  this.nextExpiration = 0;

  this.checkExpiration = function(domainer, worker) {
    var currentTime = new Date().getTime();
    if(currentTime > this.nextExpiration) {
      // we're expired, reset and call remoteDAO to reload
      this.nextExpiration = currentTime + (this.expirationPeriod*1000);
      domainer.withRemoteDictionary(worker);
    } else {
      domainer.withLocalDictionary(worker);
    }
  };
}
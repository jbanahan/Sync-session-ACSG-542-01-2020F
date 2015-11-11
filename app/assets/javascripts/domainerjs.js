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

  // get a specific record type by UID 
  this.recordType = function(uid) {
    return this.recordTypes[uid];
  };

  // get a specific field by UID
  this.field = function(uid) {
    return this.fields[uid];
  };

  //do not call, use other registerMethods
  this.registerSomething = function(obj, dataContainer, name) {
    var uid = obj.uid;

    if(!uid) {
      throw new Error(name+" must have uid property.");
    }

    var oldObj = dataContainer[uid];
    
    if(oldObj && oldObj!==obj) {
      console.log("WARNING: Replacing "+name+" \""+uid+"\" with a new object.");
    }
    dataContainer[uid] = obj;
  };

  // add a record type
  this.registerRecordType = function(recordType) {
    this.registerSomething(recordType,this.recordTypes,"RecordType");
  };

  // add a field
  this.registerField = function(field) {
    if(!field.recordType) {
      throw new Error("Field must have recordType property.");
    }
    if(!this.recordType(field.recordType.uid)) {
      throw new Error("Field's recordType ("+field.recordType.uid+") is not registered.");
    }
    this.registerSomething(field,this.fields,"Field");
  };

  // get array of all fields for a record type
  // returns an array that is unlinked from the internals of the object, so you can manipulate it
  this.fieldsByRecordType = function(recordType) {
    var dataArray = [], dataObject = this.fields;
    for(var o in dataObject) {
      if(dataObject.hasOwnProperty(o) && dataObject[o].recordType===recordType) {
        dataArray.push(dataObject[o]);
      }
    }
    return dataArray;
  };

};
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
};
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
var regExp = /_test_/;
db.getMongo().getDBNames().filter(function(name){
  return name.match(regExp)
}).forEach(function(name){
  print(name);
  var thedb = db.getMongo().getDB( name );
  thedb.dropDatabase();
});


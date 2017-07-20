# firebase-mock-functions

Test your Firebase database triggers offline

## Example usage

```javascript
var chai = require('chai');
chai.use(require('chai-as-promised'));

var FakeDatabase = require('firebase-mock-functions');
var db = new FakeDatabase();
db.override();
db.database.autoFlush(true);

// Your Firebase functions "index.js".
// This contains a function which sums /items values and saves to /total
var index = require('index');

db.setFunctionsModule(index);

describe('count total', function() {

  beforeEach(function() {
    return db.setWithoutTriggers('/', { items: { one: 1, two: 2}, total: 3 });
  });

  it('updates "/total" when a new item is added', function() {
    return db.write('/items/three', 3)
    .then(function() { return db.value('/total') })
    .should.eventually.equal(6);
  });

});
```

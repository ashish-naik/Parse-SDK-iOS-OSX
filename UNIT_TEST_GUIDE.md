# Unit Test Guide for PR 1863

## PR Summary
**Commit**: 07b9c62  
**Title**: Inject __type = @"Object" if missing but className/objectId present

## Changes Made

### File: `Parse/Parse/Source/PFDecoder.m`

The PR modifies the `decodeDictionary:` method in `PFDecoder` to add logic that:

1. **Checks** if `__type` is missing but `className` and `objectId` are present
2. **Determines** if the dictionary has additional fields beyond basic pointer keys (`className`, `objectId`, `localId`)
3. **Injects** `__type = @"Object"` if additional fields are present
4. **Preserves** the legacy dictionary path for bare pointer stubs (objects with only pointer keys)

### Code Changes (lines 50-71):
```objc
// Inject __type = @"Object" if missing but className/objectId present and on 
// the presence of additional data fields so that bare pointer stubs continue 
// to fall back to the legacy dictionary path.
if (!type && dictionary[@"className"] && dictionary[@"objectId"]) {
    static NSSet<NSString *> *pointerKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pointerKeys = [NSSet setWithObjects:@"className", @"objectId", @"localId", nil];
    });
    BOOL hasAdditionalFields = NO;
    for (NSString *key in dictionary) {
        if (![pointerKeys containsObject:key]) {
            hasAdditionalFields = YES;
            break;
        }
    }
    if (!hasAdditionalFields) {
        return dictionary;
    }
    NSMutableDictionary *mutable = [dictionary mutableCopy];
    mutable[@"__type"] = @"Object";
    type = @"Object";
    dictionary = mutable;
}
```

## Test Coverage

### Existing Tests to Verify

The following existing test files should pass without modification:

1. **`Parse/Tests/Unit/DecoderTests.m`**
   - Tests the main decoder functionality
   - Includes tests for:
     - `testDecodingPointers` - Tests pointer decoding with explicit `__type: Pointer`
     - `testDecodingObjects` - Tests object decoding with explicit `__type: Object`
     - `testDecodingObjectsWithDates` - Tests objects with additional fields (updatedAt, createdAt)
     - `testDecodingUnknownType` - Tests fallback to dictionary for unknown types

2. **`Parse/Tests/Unit/ObjectFileCoderTests.m`**
   - Tests object encoding/decoding
   - Should verify proper handling of objects with/without __type

3. **`Parse/Tests/Unit/FieldOperationDecoderTests.m`**
   - Tests field operation decoding
   - May indirectly test object decoding scenarios

### New Test Cases to Add (Recommended)

To fully test the new functionality, consider adding these test cases to `DecoderTests.m`:

```objc
// Test 1: Bare pointer stub (no __type, only pointer keys) - should return dictionary
- (void)testDecodingBarePointerStub {
    PFDecoder *decoder = [[PFDecoder alloc] init];
    
    NSDictionary *barePointer = @{
        @"className": @"TestClass",
        @"objectId": @"test123"
    };
    
    NSDictionary *decoded = [decoder decodeObject:@{ @"pointer": barePointer }];
    
    // Should return the dictionary as-is, not convert to PFObject
    NSDictionary *result = decoded[@"pointer"];
    XCTAssertTrue([result isKindOfClass:[NSDictionary class]]);
    XCTAssertFalse([result isKindOfClass:[PFObject class]]);
    XCTAssertEqualObjects(result[@"className"], @"TestClass");
    XCTAssertEqualObjects(result[@"objectId"], @"test123");
    XCTAssertNil(result[@"__type"]);
}

// Test 2: Object with additional fields (no __type) - should inject __type
- (void)testDecodingObjectWithAdditionalFieldsNoType {
    PFDecoder *decoder = [[PFDecoder alloc] init];
    
    NSDictionary *objectData = @{
        @"className": @"TestClass",
        @"objectId": @"test123",
        @"name": @"Test Name",
        @"value": @42
    };
    
    NSDictionary *decoded = [decoder decodeObject:@{ @"object": objectData }];
    
    // Should convert to PFObject because it has additional fields
    PFObject *object = decoded[@"object"];
    XCTAssertTrue([object isKindOfClass:[PFObject class]]);
    XCTAssertEqualObjects(object.parseClassName, @"TestClass");
    XCTAssertEqualObjects(object.objectId, @"test123");
    XCTAssertEqualObjects(object[@"name"], @"Test Name");
    XCTAssertEqualObjects(object[@"value"], @42);
}

// Test 3: Object with localId and additional fields - should inject __type
- (void)testDecodingObjectWithLocalIdAndAdditionalFields {
    PFDecoder *decoder = [[PFDecoder alloc] init];
    
    NSDictionary *objectData = @{
        @"className": @"TestClass",
        @"objectId": @"test123",
        @"localId": @"local456",
        @"customField": @"value"
    };
    
    NSDictionary *decoded = [decoder decodeObject:@{ @"object": objectData }];
    
    // Should convert to PFObject because it has a field beyond pointer keys
    PFObject *object = decoded[@"object"];
    XCTAssertTrue([object isKindOfClass:[PFObject class]]);
    XCTAssertEqualObjects(object[@"customField"], @"value");
}

// Test 4: Bare pointer with localId only - should return dictionary
- (void)testDecodingBarePointerWithLocalId {
    PFDecoder *decoder = [[PFDecoder alloc] init];
    
    NSDictionary *barePointer = @{
        @"className": @"TestClass",
        @"objectId": @"test123",
        @"localId": @"local456"
    };
    
    NSDictionary *decoded = [decoder decodeObject:@{ @"pointer": barePointer }];
    
    // Should return dictionary since it only has pointer keys
    NSDictionary *result = decoded[@"pointer"];
    XCTAssertTrue([result isKindOfClass:[NSDictionary class]]);
    XCTAssertFalse([result isKindOfClass:[PFObject class]]);
}
```

## Test Execution Instructions

### Prerequisites
- macOS with Xcode 15 or 16 installed
- Ruby 3.x with Bundler
- Git submodules initialized

### Setup
```bash
cd /path/to/Parse-SDK-iOS-OSX
git submodule update --init --recursive
gem install bundler -v 2.5.22
bundle install
```

### Run Tests

#### Option 1: Using the provided script
```bash
./run_tests.sh
```

#### Option 2: Using rake directly
```bash
# Run iOS tests
bundle exec rake test:ios

# Run macOS tests  
bundle exec rake test:macos

# Run all tests
bundle exec rake test:ios test:macos
```

#### Option 3: Using Xcode
1. Open `Parse.xcworkspace` in Xcode
2. Select the `Parse-iOS` or `Parse-macOS` scheme
3. Press `Cmd+U` to run tests

### Expected Results

All existing tests should pass, including:

✅ **DecoderTests**
- `testDecodingPointers` - Pointer decoding still works
- `testDecodingObjects` - Object decoding with explicit __type still works  
- `testDecodingObjectsWithDates` - Objects with dates still work
- All other decoder tests

✅ **ObjectFileCoderTests**
- All object encoding/decoding tests should pass

✅ **Other Unit Tests**
- All 100+ unit test files should pass

### Test Failures to Watch For

If tests fail, check for:

1. **Regression in pointer handling**: Bare pointers should still be treated as dictionaries
2. **Object decoding failures**: Objects with additional fields should be properly decoded
3. **Performance issues**: The static dispatch_once optimization should prevent overhead
4. **Edge cases**: Objects with only className (no objectId) should not be affected

## CI/CD Integration

The GitHub Actions CI will automatically run tests on:
- iOS 17 and 18
- macOS 14 and 15
- tvOS 17 and 18
- watchOS 10 and 11
- Xcode 15 and 16

Monitor the CI results at:
```
https://github.com/ashish-naik/Parse-SDK-iOS-OSX/actions
```

## Manual Testing Scenarios

Beyond unit tests, consider these integration test scenarios:

1. **Fetch object from server** - Verify objects fetched from Parse Server decode correctly
2. **Local datastore** - Test objects saved/retrieved from local datastore
3. **Nested objects** - Test objects with nested pointers and full objects
4. **Query results** - Verify query results with includes decode properly

## Documentation

Update documentation if needed:
- API documentation for PFDecoder if public behavior changed
- iOS Guide if developer-facing behavior changed
- CHANGELOG.md with the fix/feature description

## Checklist

- [x] Code changes reviewed and understood
- [x] Existing tests identified
- [ ] New test cases added (recommended)
- [ ] Tests run on macOS with Xcode
- [ ] All tests pass
- [ ] CI pipeline passes
- [ ] No performance regression
- [ ] Documentation updated (if needed)
- [ ] CHANGELOG.md updated

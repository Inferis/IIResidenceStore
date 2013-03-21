IIResidenceStore
================

`IIResidenceStore` is my own implementation of `TBUserIdentidy` by [@qnoid](http://twitter.com/qnoid). I found his implementation to a bit confusing and wanted to take a more layered approach: make an api (`IIResidenceStore`) and then some controllers and views on top of that. 

That way, you'd be free on how to implement this yourself: create your own UI or use the default.

Howto
=====

Create a store
--------------

You need an instance of `IIResidenceStore` to interact with a residence store. A store needs a verifier website which implements the REST calls needed to verify residences. 

    IIResidenceStore* residenceStore = [IIResidenceStore storeWithVerifier:@"http://user-identity-nsconf.herokuapp.com/users"];

This creates a store backed by `http://user-identity-nsconf.herokuapp.com/users`. 

Register a residence in the store (aka create new user)
-------------------------------------------------------

Next, you need to register a residence with the verifier. You use the `registerResidenceForEmail:completion:` call for that. This call will remember the email locally (this info is stored in the keychain).

This method takes an email address and a completion block:

	- (void)registerResidenceForEmail:(NSString*)email completion:(void(^)(BOOL success, NSError* error))completion;

It will call the verifier, and register/create a new residence registration there. The verifier should send the user an email in which she can very the residence. The completion block is called when the request completes. This does not mean the address is verified! The completionblock will return `YES` in `success` if everything went ok. `error` might contain more error information, but this is not necessarly the case.

Verify a residence
------------------
After the user has verified a residence request, the app should check if the verification was successfull. You use the `verifyResidenceForEmail:completion:` method for that.

This method takes the same email address and another completion block:

	- (void)verifyResidenceForEmail:(NSString*)email completion:(void(^)(BOOL success, NSError* error))completion;

It will check with the verifier if the email/residence has been verified by the user. It will return `YES` in `success` if that is the case. `error` might contain more error information, but this is not necessarly the case. After you have successfully verified an email, you can use the other methods to get to information.

Checking state
--------------
Check if an email is already registered:

	- (BOOL)isEmailRegistered:(NSString*)email;

This will return `YES` if the email is registered. This does not check with the verifier, but just the local datastore. This will only return `YES` if the registration call was succesfully in the past.

Check if an email is already verified:

	- (BOOL)isEmailVerified:(NSString*)email;

This will return `YES` if the email is registered and verified. This does not check with the verifier, but just the local datastore. This will only return `YES` if both the registration and verification calls were succesfully in the past.

Get the residence token:

	- (NSString*)residenceTokenForEmail:(NSString*)email;

Returns the residence token supplied by the verification call for an email address. This will return `nil` if the residence was not registered or verified. You can use this token to authorize api calls or whatever.

Get all local emails:

	- (NSArray*)allEmails;

Returns a list of local stored emails. These are both unregistered, registered, unverified and verified addresses. You can use the state calls above to check which can be used.

Configuration
-------------
Remove all local residence information:

	- (BOOL)removeAllResidences;

This clears the local information from the keychain. 

	@property (nonatomic, strong, readonly) NSString* verifier;	

This returns the address of the verifier of the current store.

	@property (nonatomic, assign) NSTimeInterval verifierTimeout;

Specifies a timeout value for the calls to the verifier. This defaults to 30 seconds. 

Keep in mind
============
Email adresses are case-insensitive. `bla@foo.bar` will be the same as `BLA@foo.BAR`.
Verifier endpoint addresses *are* case-sensitive. This is important because:
Residence info is stored in the keychain. This means it cannot be read by other applications. Each store's info is stored separately. This also means that the information will live on even if you delete and reinstall the app. The information will not persist in backups (since we assume that another device is another residence).


Requirements
============
This thing requires ARC and a fairly recent version of Xcode (4.6 or so). It only runs on iOS6 or higher.

Don't forget to reference the `Security` framework.


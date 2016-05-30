//
//  XMPPMUCLightTests.m
//  XMPPFrameworkTests
//
//  Created by Andres on 5/30/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"
#import "XMPPMUCLight.h"

@interface XMPPMUCLightTests: XCTestCase <XMPPMUCLightDelegate>

@property (nonatomic, strong) XCTestExpectation *delegateResponseExpectation;

@end

@implementation XMPPMUCLightTests

- (void)setUp {
	[super setUp];
}

- (void)tearDown {
	[super tearDown];
}

- (void)testDiscoverRoomsForServiceNamed {
	self.delegateResponseExpectation = [self expectationWithDescription:@"Slot Response"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPMUCLight *mucLight = [[XMPPMUCLight alloc] init];

	[mucLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[mucLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {

		//  <iq from='hag66@shakespeare.lit/pda'
		//      id='h7ns81g'
		//      to='shakespeare.lit'
		//      type='get'>
		//    <query xmlns='http://jabber.org/protocol/disco#items'/>
		//  </iq>

		XCTAssertNotNil([element elementForName:@"query" xmlns:@"http://jabber.org/protocol/disco#items"]);
		XCTAssertEqualObjects([element attributeForName:@"type"].stringValue, @"get");
		XCTAssertEqualObjects([element attributeForName:@"to"].stringValue, @"muclight.test.com");

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeSuccessIQWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};

	[mucLight discoverRoomsForServiceNamed:@"muclight.test.com"];

	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];

}

- (void)xmppMUCLight:(XMPPMUCLight *)sender didDiscoverRooms:(NSArray *)rooms forServiceNamed:(NSString *)serviceName {
	XCTAssertEqualObjects(serviceName, @"muclight.test.com");
	XCTAssertEqual(4, rooms.count);

	[self.delegateResponseExpectation fulfill];
}


- (void)testFailToDiscoverRoomsForServiceNamed {
	self.delegateResponseExpectation = [self expectationWithDescription:@"Slot Response"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPMUCLight *mucLight = [[XMPPMUCLight alloc] init];

	[mucLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[mucLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeErrorIQWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};

	[mucLight discoverRoomsForServiceNamed:@"muclight.test.com"];

	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];

}

- (void)xmppMUCLight:(XMPPMUCLight *)sender failedToDiscoverRoomsForServiceNamed:(NSString *)serviceName withError:(NSError *)error {
	XCTAssertEqualObjects(serviceName, @"muclight.test.com");
	[self.delegateResponseExpectation fulfill];
}


- (void)testChangeAffiliation {
	self.delegateResponseExpectation = [self expectationWithDescription:@"Slot Response"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPMUCLight *mucLight = [[XMPPMUCLight alloc] init];

	[mucLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[mucLight activate:streamTest];
	[streamTest fakeMessageResponse:[self fakeMessageChangeAffiliation]];

	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppMUCLight:(XMPPMUCLight *)sender changedAffiliation:(NSString *)affiliation roomJID:(XMPPJID *)roomJID {
	XCTAssertEqualObjects(affiliation, @"member");
	XCTAssertEqualObjects(roomJID.full, @"coven@muclight.shakespeare.lit");
	[self.delegateResponseExpectation fulfill];
}

- (XMPPMessage *)fakeMessageChangeAffiliation {
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<message from='coven@muclight.shakespeare.lit'"];
	[s appendString: @"         to='user2@shakespeare.lit'"];
	[s appendString: @"         type='groupchat'"];
	[s appendString: @"         id='createnotif'>"];
	[s appendString: @"    <x xmlns='urn:xmpp:muclight:0#affiliations'>"];
	[s appendString: @"        <version>aaaaaaa</version>"];
	[s appendString: @"        <user affiliation='member'>user2@shakespeare.lit</user>"];
	[s appendString: @"    </x>"];
	[s appendString: @"    <body />"];
	[s appendString: @"</message>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPMessage *message = [XMPPMessage messageFromElement:[doc rootElement]];
	return message;
}

- (XMPPIQ *)fakeErrorIQWithID:(NSString *) elementID{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq to='crone1@shakespeare.lit/desktop'"];
	[s appendString: @"    id='member1'"];
	[s appendString: @"    from='muclight.test.com'"];
	[s appendString: @"    type='error'>"];
	[s appendString: @"    <error type='cancel'>"];
	[s appendString: @"        <not-allowed xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>"];
	[s appendString: @"    </error>"];
	[s appendString: @"</iq>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];

	return iq;
}

- (XMPPIQ *)fakeSuccessIQWithID:(NSString *) elementID{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq from='muclight.test.com'"];
	[s appendString: @"    id='zb8q41f4'"];
	[s appendString: @"    to='hag66@shakespeare.lit/pda'"];
	[s appendString: @"    type='result'>"];
	[s appendString: @"    <query xmlns='http://jabber.org/protocol/disco#items'>"];
	[s appendString: @"        <item jid='heath@muclight.shakespeare.lit' name='A Lonely Heath' version='1'/>"];
	[s appendString: @"        <item jid='coven@muclight.shakespeare.lit' name='A Dark Cave' version='2'/>"];
	[s appendString: @"        <item jid='forres@muclight.shakespeare.lit' name='The Palace' version='3'/>"];
	[s appendString: @"        <item jid='inverness@muclight.shakespeare.lit'"];
	[s appendString: @"              name='Macbeth&apos;s Castle'"];
	[s appendString: @"              version='4'/>"];
	[s appendString: @"    </query>"];
	[s appendString: @"</iq>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];

	return iq;
}

@end

import assert from "node:assert/strict";
import test from "node:test";
import {
  parseSesEvent,
  preferredProviderStatus,
  snsStringToSign,
  snsURLAllowed
} from "./sesEvents.js";

const topicArn = "arn:aws:sns:us-east-1:123456789012:chillscript-ses-events";

test("SNS URL validation only permits the expected regional AWS endpoint", () => {
  assert.equal(snsURLAllowed(
    "https://sns.us-east-1.amazonaws.com/SimpleNotificationService-abc123.pem",
    topicArn,
    true
  ), true);
  assert.equal(snsURLAllowed(
    "https://sns.us-east-1.amazonaws.com/?Action=ConfirmSubscription&TopicArn=arn%3Aaws%3Asns%3Aus-east-1%3A123456789012%3Achillscript-ses-events&Token=x",
    topicArn,
    false
  ), true);
  assert.equal(snsURLAllowed("https://example.com/cert.pem", topicArn, true), false);
  assert.equal(snsURLAllowed("http://sns.us-east-1.amazonaws.com/cert.pem", topicArn, true), false);
});

test("SNS canonical string uses the required fixed field order", () => {
  const canonical = snsStringToSign({
    Type: "Notification",
    MessageId: "message-1",
    TopicArn: topicArn,
    Message: "payload",
    Timestamp: "2026-09-21T07:00:00.000Z",
    SignatureVersion: "2",
    Signature: "signature",
    SigningCertURL: "https://sns.us-east-1.amazonaws.com/SimpleNotificationService-abc.pem",
    Subject: "SES event"
  });
  assert.equal(canonical,
    `Message\npayload\nMessageId\nmessage-1\nSubject\nSES event\nTimestamp\n2026-09-21T07:00:00.000Z\nTopicArn\n${topicArn}\nType\nNotification\n`);
});

test("delivery events retain the delivery tag and delivery timestamp", () => {
  const event = parseSesEvent({
    eventType: "Delivery",
    mail: {
      messageId: "provider-1",
      timestamp: "2026-09-21T07:00:00.000Z",
      tags: { delivery_id: ["delivery-1"] }
    },
    delivery: {
      timestamp: "2026-09-21T07:00:02.000Z",
      processingTimeMillis: 2_000,
      smtpResponse: "250 accepted"
    }
  });
  assert.equal(event?.deliveryId, "delivery-1");
  assert.equal(event?.providerStatus, "delivered");
  assert.equal(event?.eventTimestamp.toISOString(), "2026-09-21T07:00:02.000Z");
  assert.equal(event?.suppressReason, null);
});

test("only permanent bounces and complaints trigger suppression", () => {
  const transient = parseSesEvent({
    eventType: "Bounce",
    mail: { messageId: "provider-2" },
    bounce: { bounceType: "Transient", bounceSubType: "MailboxFull" }
  });
  const permanent = parseSesEvent({
    eventType: "Bounce",
    mail: { messageId: "provider-3" },
    bounce: { bounceType: "Permanent", bounceSubType: "General" }
  });
  const complaint = parseSesEvent({
    eventType: "Complaint",
    mail: { messageId: "provider-4" },
    complaint: { complaintFeedbackType: "abuse" }
  });
  assert.equal(transient?.suppressReason, null);
  assert.equal(permanent?.suppressReason, "ses_permanent_bounce");
  assert.equal(complaint?.suppressReason, "ses_complaint");
});

test("terminal provider states cannot be overwritten by a later delivery event", () => {
  assert.equal(preferredProviderStatus("bounced", "delivered"), "bounced");
  assert.equal(preferredProviderStatus("delivered", "complained"), "complained");
  assert.equal(preferredProviderStatus(null, "accepted"), "accepted");
});

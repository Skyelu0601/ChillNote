import { verifyImap } from "../src/inbox.mjs";
import { verifySmtp } from "../src/mailer.mjs";

console.log("Testing SMTP authentication without sending an email...");
await verifySmtp();
console.log("✓ SMTP connection and authentication succeeded");

console.log("Testing IMAP authentication without reading messages...");
await verifyImap();
console.log("✓ IMAP connection and authentication succeeded");

import assert from "node:assert/strict";
import test from "node:test";
import nodemailer from "nodemailer";

test("OTP email retains its recipient and text/HTML bodies with the patched mailer", async () => {
  // Stream transport builds the same MIME message without SMTP, credentials,
  // network access, or delivery to a real recipient.
  const transport = nodemailer.createTransport({
    streamTransport: true,
    buffer: true,
    newline: "unix",
  });
  const result = await transport.sendMail({
    from: "Hasani Payroll <payroll@example.test>",
    to: "employee@example.test",
    subject: "Your verification code",
    text: "Your verification code is 123456.",
    html: "<p>Your verification code is <strong>123456</strong>.</p>",
  });

  assert.deepEqual(result.envelope, {
    from: "payroll@example.test",
    to: ["employee@example.test"],
  });
  const message = result.message.toString("utf8");
  assert.match(message, /Subject: Your verification code/);
  assert.match(message, /Content-Type: multipart\/alternative/);
  assert.match(message, /Your verification code is 123456\./);
  assert.match(message, /<strong>123456<\/strong>/);
  transport.close();
});

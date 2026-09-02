import nodemailer from "nodemailer";
import { mailConfig } from "./config.mjs";

export function createMailer() {
  const config = mailConfig();
  return nodemailer.createTransport({
    host: config.smtp.host,
    port: config.smtp.port,
    secure: config.smtp.secure,
    auth: {
      user: config.user,
      pass: config.password,
    },
    disableFileAccess: true,
    disableUrlAccess: true,
  });
}

export async function verifySmtp() {
  const transporter = createMailer();
  await transporter.verify();
  transporter.close();
}

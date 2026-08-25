import { z } from "zod";

const environmentSchema = z.enum(["sandbox", "production"]);
const localeSchema = z.string().min(1).max(35);
const timeZoneSchema = z.string().min(1).max(100);
const authorizationStatusSchema = z.string().min(1).max(40).optional();

export const apnsDeviceTokenSchema = z.string().regex(/^[a-fA-F0-9]{64,256}$/);
export const fcmRegistrationSchema = z.string()
  .min(20)
  .max(4096)
  .refine((value) => !/\s/.test(value), "FCM registration must not contain whitespace");

export const pushDeviceSchema = z.union([
  z.object({
    platform: z.literal("android"),
    token: fcmRegistrationSchema,
    environment: environmentSchema,
    locale: localeSchema,
    timeZone: timeZoneSchema,
    authorizationStatus: authorizationStatusSchema
  }),
  z.object({
    // Existing iOS releases predate the platform field, so omission remains iOS.
    platform: z.literal("ios").default("ios"),
    token: apnsDeviceTokenSchema,
    environment: environmentSchema,
    locale: localeSchema,
    timeZone: timeZoneSchema,
    authorizationStatus: authorizationStatusSchema
  })
]);

const pushTargetSchema = z.union([apnsDeviceTokenSchema, fcmRegistrationSchema]);

export const pushDeviceDeleteSchema = z.object({ token: pushTargetSchema });

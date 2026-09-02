import fs from "node:fs/promises";
import { affiliateSignupLink, htmlTemplatePath, templatePath } from "./config.mjs";

export async function loadTemplate(filePath = templatePath) {
  return fs.readFile(filePath, "utf8");
}

export async function loadHtmlTemplate(filePath = htmlTemplatePath) {
  return fs.readFile(filePath, "utf8");
}

export function renderTemplate(template, lead) {
  const values = {
    creator_name: lead.creator_name,
    personalization: lead.personalization,
    audience_fit: lead.audience_fit,
    affiliate_signup_link: affiliateSignupLink,
  };

  const output = template.replace(/\{\{([a-z_]+)\}\}/g, (_, key) => {
    const value = values[key]?.trim();
    if (!value) throw new Error(`Lead ${lead.id} is missing template value: ${key}`);
    return value;
  });

  const unresolved = output.match(/\{\{[^}]+\}\}/g);
  if (unresolved) {
    throw new Error(`Unresolved template placeholders: ${unresolved.join(", ")}`);
  }
  return output.trim();
}

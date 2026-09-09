// The connected Resend account is currently verified for savemypad.com.
// Keep the visible SideCar name while using an authenticated sender domain so
// verification and password-reset messages are accepted instead of rejected by
// the SMTP provider.
export const defaultAuthEmailSender = "SideCar <verify@savemypad.com>";
export const defaultAuthEmailReplyTo = "verify@savemypad.com";

export function authEmailEnvelope(params: {
  to: string;
  sender?: string;
  subject: string;
  text: string;
  html: string;
}): Record<string, unknown> {
  return {
    to: params.to,
    from: params.sender?.trim() || defaultAuthEmailSender,
    replyTo: defaultAuthEmailReplyTo,
    message: {
      subject: params.subject,
      text: params.text,
      html: params.html,
    },
  };
}

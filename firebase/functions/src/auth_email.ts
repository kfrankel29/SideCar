export const defaultAuthEmailSender = "SideCar <verify@ride-sidecar.com>";
export const defaultAuthEmailReplyTo = "verify@ride-sidecar.com";

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
